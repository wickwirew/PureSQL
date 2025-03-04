
//
//  ExprTypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections

/// Performs type checking and type inference on expressions.
struct ExprTypeChecker {
    private(set) var inferenceState: InferenceState
    /// The environment in which the query executes. Any joined in tables
    /// will be added to this.
    private(set) var env: Environment
    /// The entire database schema
    private let schema: Schema
    /// Any diagnostics that are emitted during compilation
    private(set) var diagnostics = Diagnostics()
    
    private let pragmas: FeatherPragmas
    
    init(
        inferenceState: InferenceState,
        env: Environment,
        schema: Schema,
        pragmas: FeatherPragmas
    ) {
        self.inferenceState = inferenceState
        self.env = env
        self.schema = schema
        self.pragmas = pragmas
    }

    mutating func typeCheck<E: ExprSyntax>(_ expr: E) -> Type {
        return expr.accept(visitor: &self)
    }
    
    private mutating func typeCheck<E: ExprSyntax>(_ exprs: [E]) -> [Type] {
        var types: [Type] = []
        
        for expr in exprs {
            let type = expr.accept(visitor: &self)
            types.append(inferenceState.solution(for: type))
        }
        
        return types
    }
}

extension ExprTypeChecker: ExprSyntaxVisitor {
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> Type {
        return switch expr.kind {
        case let .numeric(_, isInt):
            // If it is an integer literal we cant assume it should be an int.
            isInt ? inferenceState.freshTyVar(for: expr, kind: isInt ? .integer : .float) : .real
        case .string: inferenceState.nominalType(of: "TEXT", for: expr)
        case .blob: inferenceState.nominalType(of: "BLOB", for: expr)
        case .null: inferenceState.nominalType(of: "ANY", for: expr)
        case .true, .false:
            // TODO: Should be INTEGER
            inferenceState.nominalType(of: "BOOLEAN", for: expr)
        case .currentTime, .currentDate, .currentTimestamp:
            inferenceState.nominalType(of: "TEXT", for: expr)
        case .invalid:
            inferenceState.nominalType(of: "<ERROR>", for: expr)
        }
    }
    
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> Type {
        return inferenceState.freshTyVar(forParam: expr)
    }
    
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> Type {
        if let tableName = expr.table {
            guard let result = env[tableName.value] else {
                diagnostics.add(.init(
                    "Table named '\(expr)' does not exist",
                    at: expr.range
                ))
                return inferenceState.errorType(for: expr)
            }
            
            // TODO: Maybe put this in the scheme instantiation?
            if result.isAmbiguous {
                diagnostics.add(.ambiguous(tableName.value, at: tableName.range))
            }
            
            // Table may be optionally included
            let (tableTy, isOptional) = if case let .optional(inner) = result.type {
                (inner, true)
            } else {
                (result.type, false)
            }
            
            guard case let .row(.named(columns)) = tableTy else {
                diagnostics.add(.init(
                    "'\(tableName)' is not a row, got \(tableTy)",
                    at: expr.range
                ))
                return inferenceState.errorType(for: expr)
            }

            guard let type = columns[expr.column.value] else {
                diagnostics.add(.init(
                    "Table '\(tableName)' has no column '\(expr.column)'",
                    at: expr.range
                ))
                return inferenceState.errorType(for: expr)
            }
            
            return (isOptional ? .optional(type) : type)
        } else {
            guard let result = env[expr.column.value] else {
                diagnostics.add(.init(
                    "Column '\(expr.column)' does not exist",
                    at: expr.range
                ))
                return inferenceState.errorType(for: expr)
            }
            
            // TODO: Maybe put this in the scheme instantiation?
            if result.isAmbiguous {
                diagnostics.add(.ambiguous(expr.column.value, at: expr.column.range))
            }
            
            // Make sure to record the type in the inference state since
            // the type was pulled from the environment
            inferenceState.record(type: result.type, for: expr)
            return (result.type)
        }
    }
    
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> Type {
        let rhs = expr.rhs.accept(visitor: &self)
        
        guard let scheme = env[prefix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid prefix operator",
                at: expr.operator.range
            ))
            return inferenceState.errorType(for: expr)
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = inferenceState.instantiate(scheme)
        inferenceState.unify(fnType, with: .fn(params: [rhs], ret: tv), at: expr.range)
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> Type {
        let lTy = expr.lhs.accept(visitor: &self)
        let rTy = expr.rhs.accept(visitor: &self)
        
        guard let scheme = env[infix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid infix operator",
                at: expr.operator.range
            ))
            return .error
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = inferenceState.instantiate(scheme)
        inferenceState.unify(fnType, with: .fn(params: [inferenceState.solution(for: lTy), rTy], ret: tv), at: expr.range)
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> Type {
        let lhs = expr.lhs.accept(visitor: &self)
        
        guard let scheme = env[postfix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid postfix operator",
                at: expr.operator.range
            ))
            return .error
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = inferenceState.instantiate(scheme)
        inferenceState.unify(fnType, with: .fn(params: [lhs], ret: tv), at: expr.range)
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> Type {
        let value = expr.value.accept(visitor: &self)
        let lower = expr.lower.accept(visitor: &self)
        let upper = expr.upper.accept(visitor: &self)
        let allTypes = [value, lower, upper]
        
        inferenceState.unify(all: allTypes, at: expr.range)
        
        let between = inferenceState.instantiate(Builtins.between)
        inferenceState.unify(between, with: .fn(params: allTypes, ret: .bool), at: expr.range)
        return .bool
    }
    
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> Type {
        let argTys = typeCheck(expr.args)
        
        guard let scheme = env[function: expr.name.value, argCount: argTys.count] else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.range))
            return .error
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        inferenceState.unify(inferenceState.instantiate(scheme), with: .fn(params: argTys, ret: tv), at: expr.range)
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: borrowing CastExprSyntax) -> Type {
        // We don't care about the output type, it is just going to be casted.
        _ = expr.expr.accept(visitor: &self)
        return inferenceState.nominalType(of: expr.ty.name.value, for: expr)
    }
    
    mutating func visit(_ expr: borrowing ExpressionSyntax) -> Type {
        fatalError("TODO: Clean this up. Should never get called. It's `accept` calls the wrapped method, not this")
    }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> Type {
        let ret = inferenceState.freshTyVar(for: expr)
        var whenTys = typeCheck(expr.whenThen.map(\.when))
        
        var thenTys = typeCheck(expr.whenThen.map(\.then))
        thenTys.append(ret)
        
        if let caseType = expr.case?.accept(visitor: &self) {
            // Each when should have same type as case
            whenTys.append(caseType)
        } else {
            // No case expr, so each when should be a bool
            whenTys.append(.bool)
        }
        
        if let elseType = expr.else?.accept(visitor: &self) {
            thenTys.append(elseType)
        }
        
        inferenceState.unify(all: whenTys, at: expr.range)
        inferenceState.unify(all: thenTys, at: expr.range)
        
        return inferenceState.solution(for: ret)
    }
    
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> Type {
        return .row(.unnamed(typeCheck(expr.exprs)))
    }
    
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> Type {
        var typeChecker = StmtTypeChecker(env: env, schema: schema, inferenceState: inferenceState, pragmas: pragmas)
        let signature = typeChecker.signature(for: expr.select)
        let type: Type = .row(.named(signature.output.columns))
        // Make sure to update our inference state
        inferenceState = typeChecker.inferenceState
        // Using typeCheckers `allDiagnostics` would include diags
        // even from within the inference state
        diagnostics.merge(typeChecker.diagnostics)
        // Record the result type in the state
        inferenceState.record(type: type, for: expr)
        return type
    }
    
    mutating func visit(_ expr: borrowing InvalidExprSyntax) -> Type {
        return inferenceState.errorType(for: expr)
    }
}
