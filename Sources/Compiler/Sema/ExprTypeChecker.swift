
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
    /// Any CTEs available to the expression
    private let ctes: [Substring: Table]
    /// Any diagnostics that are emitted during compilation
    private(set) var diagnostics = Diagnostics()
    /// Any table that is used
    private(set) var usedTableNames: Set<Substring> = []
    
    private let pragmas: OtterPragmas
    
    init(
        inferenceState: InferenceState,
        env: Environment,
        schema: Schema,
        ctes: [Substring: Table],
        pragmas: OtterPragmas
    ) {
        self.inferenceState = inferenceState
        self.env = env
        self.schema = schema
        self.ctes = ctes
        self.pragmas = pragmas
    }

    mutating func typeCheck(_ expr: any ExprSyntax) -> Type {
        return expr.accept(visitor: &self)
    }
    
    private mutating func typeCheck(_ exprs: [any ExprSyntax]) -> [Type] {
        var types: [Type] = []
        
        for expr in exprs {
            let type = expr.accept(visitor: &self)
            types.append(inferenceState.solution(for: type))
        }
        
        return types
    }
    
    private mutating func typeCheck(select: SelectStmtSyntax) -> Type {
        var typeChecker = StmtTypeChecker(
            env: Environment(parent: env),
            schema: schema,
            ctes: ctes,
            inferenceState: inferenceState,
            pragmas: pragmas
        )
        let signature = typeChecker.signature(for: select)
        let type: Type = .row(.fixed(signature.output.allColumns.map(\.value)))
        // Make sure to update our inference state
        inferenceState = typeChecker.inferenceState
        // Using typeCheckers `allDiagnostics` would include diags
        // even from within the inference state
        diagnostics.merge(typeChecker.diagnostics)
        // Record the result type in the state
        usedTableNames = typeChecker.usedTableNames
        return type
    }
    
    private mutating func value<Value>(
        from result: Environment.LookupResult<Value>,
        at location: SourceLocation,
        name: Substring
    ) -> Value? {
        switch result {
        case let .success(value):
            return value
        case let .ambiguous(value):
            diagnostics.add(.ambiguous(name, at: location))
            return value
        case let .columnDoesNotExist(column):
            diagnostics.add(.columnDoesNotExist(column, at: location))
            return nil
        case let .tableDoesNotExist(table):
            diagnostics.add(.tableDoesNotExist(table, at: location))
            return nil
        case let .schemaDoesNotExist(schema):
            diagnostics.add(.schemaDoesNotExist(schema, at: location))
            return nil
        }
    }
    
    /// Will instatiate the function's type scheme and perform any checks
    /// define by the function.
    private mutating func instanteAndCheck(
        fn: Function,
        argCount: Int,
        argTypes: @autoclosure () -> [Type],
        argExprs: borrowing @autoclosure () -> [any ExprSyntax],
        location: SourceLocation
    ) -> Type {
        let type = inferenceState.instantiate(fn, preferredArgCount: argCount)
        
        guard let check = fn.check else { return type }
        check(argTypes(), argExprs(), location, &diagnostics)
        return type
    }
}

extension ExprTypeChecker: ExprSyntaxVisitor {
    mutating func visit(_ expr: LiteralExprSyntax) -> Type {
        return switch expr.kind {
        case let .numeric(_, isInt): inferenceState.freshTyVar(for: expr, kind: isInt ? .integer : .float)
        case .string: inferenceState.nominalType(of: "TEXT", for: expr)
        case .blob: inferenceState.nominalType(of: "BLOB", for: expr)
        case .null: .optional(inferenceState.freshTyVar(for: expr, kind: .general))
        case .true, .false: inferenceState.nominalType(of: "INTEGER", for: expr)
        case .currentTime, .currentDate, .currentTimestamp:
            inferenceState.nominalType(of: "TEXT", for: expr)
        case .invalid: inferenceState.errorType(for: expr)
        }
    }
    
    mutating func visit(_ expr: BindParameterSyntax) -> Type {
        return inferenceState.freshTyVar(forParam: expr)
    }
    
    mutating func visit(_ expr: ColumnExprSyntax) -> Type {
        switch expr.column {
        case .all:
            if let tableName = expr.table {
                guard let table = value(
                    from: env.resolve(
                        table: tableName.value,
                        schema: expr.schema?.value
                    ),
                    at: expr.location,
                    name: tableName.value
                ) else { return inferenceState.errorType(for: expr) }
                
                return table.type
            } else {
                return .row(.fixed(env.allColumnTypes))
            }
        case let .column(column):
            guard let column = value(
                from: env.resolve(
                    column: column.value,
                    table: expr.table?.value,
                    schema: expr.schema?.value
                ),
                at: expr.location,
                name: column.value
            ) else {
                return inferenceState.errorType(for: expr)
            }
            
            // Make sure to record the type in the inference state since
            // the type was pulled from the environment
            inferenceState.record(type: column, for: expr)
            return column
        }
    }
    
    mutating func visit(_ expr: PrefixExprSyntax) -> Type {
        let rhs = expr.rhs.accept(visitor: &self)
        
        guard let fn = env.resolve(prefix: expr.operator.operator) else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid prefix operator",
                at: expr.operator.location
            ))
            return inferenceState.errorType(for: expr)
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = inferenceState.instantiate(fn, preferredArgCount: 1)
        inferenceState.unify(fnType, with: .fn(params: [rhs], ret: tv), at: expr.location)
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: InfixExprSyntax) -> Type {
        let lTy = expr.lhs.accept(visitor: &self)
        let rTy = expr.rhs.accept(visitor: &self)
        
        guard let fn = env.resolve(infix: expr.operator.operator) else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid infix operator",
                at: expr.operator.location
            ))
            return .error
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = instanteAndCheck(
            fn: fn,
            argCount: 2,
            argTypes: [lTy, rTy],
            argExprs: [expr.lhs, expr.rhs],
            location: expr.location
        )
        
        inferenceState.unify(
            fnType,
            with: .fn(params: [inferenceState.solution(for: lTy), rTy], ret: tv),
            at: expr.location
        )
        
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: PostfixExprSyntax) -> Type {
        let lhs = expr.lhs.accept(visitor: &self)
        
        guard let fn = env.resolve(postfix: expr.operator.operator) else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid postfix operator",
                at: expr.operator.location
            ))
            return .error
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = instanteAndCheck(
            fn: fn,
            argCount: 1,
            argTypes: [lhs],
            argExprs: [expr.lhs],
            location: expr.location
        )
        inferenceState.unify(fnType, with: .fn(params: [lhs], ret: tv), at: expr.location)
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: BetweenExprSyntax) -> Type {
        let value = expr.value.accept(visitor: &self)
        let lower = expr.lower.accept(visitor: &self)
        let upper = expr.upper.accept(visitor: &self)
        let allTypes = [value, lower, upper]
        
        inferenceState.unify(all: allTypes, at: expr.location)
        
        let between = instanteAndCheck(
            fn: Builtins.between,
            argCount: 3,
            argTypes: allTypes,
            argExprs: [expr.value, expr.lower, expr.upper],
            location: expr.location
        )
        inferenceState.unify(between, with: .fn(params: allTypes, ret: .integer), at: expr.location)
        return .integer
    }
    
    mutating func visit(_ expr: FunctionExprSyntax) -> Type {
        let argTys = typeCheck(expr.args)
        
        guard let fn = env.resolve(function: expr.name.value) else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.location))
            return .error
        }
        
        let tv = inferenceState.freshTyVar(for: expr)
        let fnType = instanteAndCheck(
            fn: fn,
            argCount: argTys.count,
            argTypes: argTys,
            argExprs: expr.args,
            location: expr.location
        )
        
        inferenceState.unify(fnType, with: .fn(params: argTys, ret: tv), at: expr.location)
        
        return inferenceState.solution(for: tv)
    }
    
    mutating func visit(_ expr: CastExprSyntax) -> Type {
        // We don't care about the output type, it is just going to be casted.
        _ = expr.expr.accept(visitor: &self)
        return inferenceState.nominalType(of: expr.ty.name.value, for: expr)
    }
    
    mutating func visit(_ expr: CaseWhenThenExprSyntax) -> Type {
        let ret = inferenceState.freshTyVar(for: expr)
        var whenTys = typeCheck(expr.whenThen.map(\.when))
        
        var thenTys = typeCheck(expr.whenThen.map(\.then))
        thenTys.append(ret)
        
        if let caseType = expr.case?.accept(visitor: &self) {
            // Each when should have same type as case
            whenTys.append(caseType)
        } else {
            // No case expr, so each when should be a integer
            whenTys.append(.integer)
        }
        
        if let elseType = expr.else?.accept(visitor: &self) {
            thenTys.append(elseType)
        }
        
        inferenceState.unify(all: whenTys, at: expr.location)
        inferenceState.unify(all: thenTys, at: expr.location)
        
        return inferenceState.solution(for: ret)
    }
    
    mutating func visit(_ expr: GroupedExprSyntax) -> Type {
        return .row(.fixed(typeCheck(expr.exprs)))
    }
    
    mutating func visit(_ expr: SelectExprSyntax) -> Type {
        let type = typeCheck(select: expr.select)
        inferenceState.record(type: type, for: expr)
        return type
    }
    
    mutating func visit(_ expr: ExistsExprSyntax) -> Type {
        _ = typeCheck(select: expr.select)
        return .integer
    }
    
    mutating func visit(_ expr: InvalidExprSyntax) -> Type {
        return inferenceState.errorType(for: expr)
    }
}
