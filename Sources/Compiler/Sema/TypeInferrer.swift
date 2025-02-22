//
//  TypeInferrer.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections

struct TypeInferrer {
    /// The environment in which the query executes. Any joined in tables
    /// will be added to this.
    private var env: Environment
    /// The entire database schema
    private let schema: Schema
    /// Any diagnostics that are emitted during compilation
    private(set) var diagnostics: Diagnostics
    /// Number of type variables. Incremented each time a new
    /// fresh type var is created so all are unique
    private var tyVarCounter = 0
    /// The type of the bind parameter. Note: This will not be
    /// the final type. The overall substitution will have to be applied
    /// to the type.
    private var parameterTypes: [BindParameterSyntax.Index: Type] = [:]
    /// Any constraints over a type. These are not constraints as in a
    /// constraint based inference algorithm but rather constraints on a type
    /// like type classes, protocols, or interfaces.
    private var constraints: Constraints = [:]
    /// We are not only inferring types but potential names for the parameters.
    /// Any result will be added here
    private var parameterNames: [BindParameterSyntax.Index: Substring] = [:]
    
    init(
        env: Environment = Environment(),
        schema: Schema,
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.env = env
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    /// Calculates the signature for a single expression.
    mutating func signature<E: ExprSyntax>(for expr: E) -> Signature {
        let (ty, sub, _) = expr.accept(visitor: &self)
        return signature(ty: ty, sub: sub, outputCardinality: .many)
    }
    
    /// Calculates the solution of an entire statement.
    mutating func signature<S: StmtSyntax>(for stmt: S) -> Signature {
        let (ty, sub) = stmt.accept(visitor: &self)
        
        // Since its a statement we need to also infer whether or not
        // the exepected result count is a single or many rows
        var singleOuputInferer = CardinalityInferrer(schema: schema)
        let cardinality = singleOuputInferer.cardinality(for: stmt)
        
        return signature(ty: ty, sub: sub, outputCardinality: cardinality)
    }
    
    /// Calculates the final inferred signature of the statement
    private mutating func signature(
        ty: Type?,
        sub: Substitution,
        outputCardinality: Signature.Cardinality
    ) -> Signature {
        let constraints = finalizeConstraints(with: sub)
        
        return Signature(
            parameters: parameterTypes.reduce(into: [:]) { params, value in
                params[value.key] = Signature.Parameter(
                    type: finalType(
                        for: value.value,
                        substitution: sub,
                        constraints: constraints
                    ),
                    index: value.key,
                    name: parameterNames[value.key]
                )
            },
            output: ty.map { ty in
                finalType(
                    for: ty.apply(sub),
                    substitution: sub,
                    constraints: constraints
                )
            },
            outputCardinality: outputCardinality
        )
    }
    
    /// Applies the substitution to the type
    /// and validates the constraints. If no type is
    /// found one will be guessed from the constraints.
    private func finalType(
        for ty: Type,
        substitution: Substitution,
        constraints: Constraints
    ) -> Type {
        let ty = ty.apply(substitution)
        
        switch ty.apply(substitution) {
        case let .var(tv):
            // The type variable was never bound to a concrete type.
            // Check if the constraints gives any clues about a default type
            // if none just assume `ANY`
            if let constraints = constraints[tv], constraints.contains(.numeric) {
                return .integer
            }
            return .any
        case let .row(tys):
            // Finalize all of the inner types in the row.
            return .row(tys.mapTypes {
                finalType(
                    for: $0,
                    substitution: substitution,
                    constraints: constraints
                )
            })
        default:
            return ty
        }
    }
    
    /// Applies the substitution to the overall constraints
    /// so it is the final type to in the map
    private mutating func finalizeConstraints(
        with substitution: Substitution
    ) -> Constraints {
        var result: [TypeVariable: TypeConstraints] = [:]
        
        for (tv, constraints) in constraints {
            let ty = Type.var(tv).apply(substitution)
            
            if case let .var(tv) = ty {
                result[tv] = constraints
            } else {
                // TODO: If it is a non type variable we need to validate
                // the type meets the constraints requirements.
            }
        }
        
        return result
    }
    
    /// Creates a fresh new unique type variable
    private mutating func freshTyVar(for param: BindParameterSyntax? = nil) -> TypeVariable {
        defer { tyVarCounter += 1 }
        let ty = TypeVariable(tyVarCounter)
        if let param {
            parameterTypes[param.index] = .var(ty)
        }
        return ty
    }
    
    private mutating func instantiate(_ typeScheme: TypeScheme) -> Type {
        guard !typeScheme.typeVariables.isEmpty else { return typeScheme.type }
        let sub = Substitution(
            typeScheme.typeVariables.map { ($0, .var(freshTyVar())) },
            uniquingKeysWith: { $1 }
        )
        return typeScheme.type.apply(sub)
    }
    
    /// Unifies the two types together. Will produce a substitution if one
    /// is a type variable. If there are two nominal types they and
    /// they can be coerced en empty substitution will be returned
    private mutating func unify(
        _ ty: Type,
        with other: Type,
        at range: Range<String.Index>
    ) -> Substitution {
        ty.unify(with: other, at: range, diagnostics: &diagnostics)
    }
    
    private mutating func unify(
        all tys: [Type],
        at range: Range<String.Index>
    ) -> Substitution {
        var tys = tys.makeIterator()
        var sub: Substitution = [:]
        
        guard var lastTy = tys.next() else { return sub }
        
        while let ty = tys.next() {
            sub.merge(unify(lastTy, with: ty.apply(sub), at: range), uniquingKeysWith: { $1 })
            lastTy = ty
        }
        
        return sub
    }
    
    /// Merges the new name results. If a name is inferred
    /// it is recorded and a empty result is returned so nothign
    /// else gets that new name.
    private mutating func merge(
        names lhs: Names,
        with rhs: Names
    ) -> Names {
        switch (lhs, rhs) {
        case let (.needed(index), .some(name)):
            track(name: name, for: index)
            return .none
        case let (.some(name), .needed(index)):
            track(name: name, for: index)
            return .none
        case (.none, _):
            return rhs
        case (_, .none):
            return lhs
        default:
            return rhs
        }
    }
    
    /// Records the parameter name for the bind index
    private mutating func track(
        name: Substring,
        for index: BindParameterSyntax.Index
    ) {
        parameterNames[index] = name
    }
    
    /// Performs the inference in a new environment.
    /// Useful for subqueries that don't inhereit our current joins.
    private mutating func inNewEnvironment<Output>(
        _ action: (inout TypeInferrer) -> Output
    ) -> Output {
        var inferrer = self
        inferrer.env = Environment()
        let result = action(&inferrer)
        diagnostics = inferrer.diagnostics
        tyVarCounter = inferrer.tyVarCounter
        parameterTypes = inferrer.parameterTypes
        constraints = inferrer.constraints
        return result
    }
}

extension TypeInferrer: ExprSyntaxVisitor {
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> (Type, Substitution, Names) {
        switch expr.kind {
        case let .numeric(_, isInt):
            if isInt {
                let tv = freshTyVar()
                constraints[tv] = .numeric
                return (.var(tv), [:], .none)
            } else {
                return (.real, [:], .none)
            }
        case .string: return (.text, [:], .none)
        case .blob: return (.blob, [:], .none)
        case .null: return (.any, [:], .none)
        case .true, .false: return (.bool, [:], .none)
        case .currentTime, .currentDate, .currentTimestamp: return (.text, [:], .none)
        case .invalid: return (.error, [:], .none)
        }
    }
    
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> (Type, Substitution, Names) {
        let expr = copy expr
        let names: Names
        switch expr.kind {
        case let .named(name):
            track(name: name.value, for: expr.index)
            names = .none
        case .unnamed:
            names = .needed(index: expr.index)
        }
        
        return (.var(freshTyVar(for: expr)), [:], names)
    }
    
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> (Type, Substitution, Names) {
        if let tableName = expr.table {
            guard let result = env[tableName.value] else {
                diagnostics.add(.init(
                    "Table named '\(expr)' does not exist",
                    at: expr.range
                ))
                return (.error, [:], .some(expr.column.value))
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
                return (.error, [:], .some(expr.column.value))
            }

            guard let type = columns[expr.column.value] else {
                diagnostics.add(.init(
                    "Table '\(tableName)' has no column '\(expr.column)'",
                    at: expr.range
                ))
                return (.error, [:], .some(expr.column.value))
            }
            
            return (isOptional ? .optional(type) : type, [:], .some(expr.column.value))
        } else {
            guard let result = env[expr.column.value] else {
                diagnostics.add(.init(
                    "Column '\(expr.column)' does not exist",
                    at: expr.range
                ))
                return (.error, [:], .some(expr.column.value))
            }
            
            // TODO: Maybe put this in the scheme instantiation?
            if result.isAmbiguous {
                diagnostics.add(.ambiguous(expr.column.value, at: expr.column.range))
            }
            
            return (result.type, [:], .some(expr.column.value))
        }
    }
    
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> (Type, Substitution, Names) {
        let (t, s, n) = expr.rhs.accept(visitor: &self)
        
        guard let scheme = env[prefix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid prefix operator",
                at: expr.operator.range
            ))
            return (.error, s, n)
        }
        
        let tv: Type = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [t], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(s), n)
    }
    
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> (Type, Substitution, Names) {
        let (lTy, lSub, lNames) = expr.lhs.accept(visitor: &self)
        let (rTy, rSub, rNames) = expr.rhs.accept(visitor: &self)
        let names = merge(names: lNames, with: rNames)
        
        guard let scheme = env[infix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid infix operator",
                at: expr.operator.range
            ))
            return (.error, rSub.merging(lSub), names)
        }
        
        let tv: Type = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [lTy.apply(rSub), rTy], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(rSub, lSub), names)
    }
    
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> (Type, Substitution, Names) {
        let (t, s, n) = expr.lhs.accept(visitor: &self)
        
        guard let scheme = env[postfix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid postfix operator",
                at: expr.operator.range
            ))
            return (.error, s, n)
        }
        
        let tv: Type = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [t], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(s), n)
    }
    
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> (Type, Substitution, Names) {
        let (tys, sub, names) = visit(many: [expr.value, expr.lower, expr.upper])
        let betSub = unify(instantiate(Builtins.between), with: .fn(params: tys, ret: .bool), at: expr.range)
        return (.bool, betSub.merging(sub), names)
    }
    
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> (Type, Substitution, Names) {
        let (argTys, argSub, argNames) = visit(many: expr.args)
        
        guard let scheme = env[function: expr.name.value, argCount: argTys.count] else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.range))
            return (.error, argSub, argNames)
        }
        
        let tv: Type = .var(freshTyVar())
        let sub = unify(instantiate(scheme), with: .fn(params: argTys, ret: tv), at: expr.range)
        return (tv, sub.merging(argSub), argNames)
    }
    
    mutating func visit(_ expr: borrowing CastExprSyntax) -> (Type, Substitution, Names) {
        let (_, s, n) = expr.expr.accept(visitor: &self)
        return (.nominal(expr.ty.name.value), s, n)
    }
    
    mutating func visit(_ expr: borrowing ExpressionSyntax) -> (Type, Substitution, Names) {
        fatalError("TODO: Clean this up. Should never get called. It's `accept` calls the wrapped method, not this")
    }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> (Type, Substitution, Names) {
        let ret: Type = .var(freshTyVar())
        let (whenTys, whenSub, whenNames) = visit(many: expr.whenThen.map(\.when))
        let (thenTys, thenSub, thenNames) = visit(many: expr.whenThen.map(\.then))
        
        var sub = whenSub.merging(thenSub)
        var names = merge(names: whenNames, with: thenNames)
        
        if let (t, s, n) = expr.case?.accept(visitor: &self) {
            // Each when should have same type as case
            sub = sub.merging(unify(all: [t] + whenTys, at: expr.range), s)
            names = merge(names: names, with: n)
        } else {
            // No case expr, so each when should be a bool
            sub = sub.merging(unify(all: [.bool] + whenTys, at: expr.range))
        }
        
        if let (t, s, n) = expr.else?.accept(visitor: &self) {
            sub = sub.merging(unify(all: [t, ret] + thenTys, at: expr.range), s)
            names = merge(names: names, with: n)
        } else {
            sub = sub.merging(unify(all: [ret] + thenTys, at: expr.range))
        }
        
        return (ret, sub, names)
    }
    
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> (Type, Substitution, Names) {
        let (t, s, n) = visit(many: expr.exprs)
        return (.row(.unnamed(t)), s, n)
    }
    
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> (Type, Substitution, Names) {
        let (ty, sub) = infer(select: expr.select)
        return (ty, sub, .none)
    }
    
    func visit(_ expr: borrowing InvalidExprSyntax) -> (Type, Substitution, Names) {
        return (.error, [:], .none)
    }
    
    private mutating func visit(many exprs: [ExpressionSyntax]) -> ([Type], Substitution, Names) {
        var tys: [Type] = []
        var sub: Substitution = [:]
        var names: Names = .none
        
        for expr in exprs {
            let (t, s, n) = expr.accept(visitor: &self)
            tys.append(t.apply(sub))
            sub.merge(s, uniquingKeysWith: { $1 })
            names = merge(names: names, with: n)
        }
        
        return (tys, sub, names)
    }
}

extension TypeInferrer: StmtSyntaxVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> (Type?, Substitution) {
        fatalError()
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> (Type?, Substitution) {
        fatalError()
    }
    
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> (Type?, Substitution) {
        return infer(select: stmt)
    }
    
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> (Type?, Substitution) {
        return infer(insert: stmt)
    }
    
    mutating func visit(_ stmt: borrowing UpdateStmtSyntax) -> (Type?, Substitution) {
        return infer(update: stmt)
    }
    
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> (Type?, Substitution) {
        return infer(delete: stmt)
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> (Type?, Substitution) {
        return (nil, [:])
    }
    
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> (Type?, Substitution) {
        return stmt.statement.accept(visitor: &self)
    }
    
    mutating func visit(_ stmt: borrowing PragmaStmt) -> (Type?, Substitution) {
        return (nil, [:])
    }
}

extension TypeInferrer {
    mutating func infer(
        select: SelectStmtSyntax,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> (Type, Substitution) {
        var sub: Substitution = [:]
        
        if let cte = select.cte?.value {
            sub.merge(infer(cte: cte))
        }
        
        switch select.selects.value {
        case let .single(selectCore):
            let (type, selectSub) = infer(
                select: selectCore,
                at: select.range,
                potentialNames: potentialNames
            )
            sub.merge(selectSub)
            return (type, sub)
        case .compound:
            fatalError()
        }
    }
    
    mutating func infer(insert: InsertStmtSyntax) -> (Type, Substitution) {
        var sub: Substitution = [:]
        
        if let cte = insert.cte {
            sub.merge(infer(cte: cte))
        }
        
        guard let table = schema[insert.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(insert.tableName.name))
            return (.error, sub)
        }
        
        let inputType: Type
        if let columns = insert.columns {
            var columnTypes: [Type] = []
            for column in columns {
                guard let def = table.columns[column.value] else {
                    diagnostics.add(.columnDoesNotExist(column))
                    columnTypes.append(.error)
                    continue
                }
                
                columnTypes.append(def)
            }
            inputType = .row(.unnamed(columnTypes))
        } else {
            inputType = table.type
        }
        
        if let values = insert.values {
            let (type, selectSub) = infer(select: values.select, potentialNames: insert.columns)
            sub.merge(selectSub)
            
            // Unify the selected column list with the value types.
            sub.merge(inputType.unify(with: type, at: insert.range, diagnostics: &diagnostics))
        } else {
            // TODO: Using 'DEFALUT VALUES' make sure all columns
            // TODO: actually have default values or null
        }
        
        let (ty, retSub): (Type, Substitution) = if let returningClause = insert.returningClause {
            infer(returningClause: returningClause, sourceTable: table)
        } else {
            (.row(.empty), [:])
        }
        
        sub.merge(retSub)
        return (ty, sub)
    }
    
    mutating func infer(update: UpdateStmtSyntax) -> (Type, Substitution) {
        var sub: Substitution = [:]
        
        if let cte = update.cte {
            sub.merge(infer(cte: cte))
        }
        
        guard let table = schema[update.tableName.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(update.tableName.tableName.name))
            return (.error, sub)
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        for set in update.sets {
            let (valueType, valueSub, valueName) = set.expr.accept(visitor: &self)
            sub.merge(valueSub)
            
            switch set.column {
            // SET column = value
            case .single(let column):
                _ = merge(names: valueName, with: .some(column.value))
                
                guard let column = table.columns[column.value] else {
                    diagnostics.add(.columnDoesNotExist(column))
                    return (.error, sub)
                }
                
                sub.merge(unify(column, with: valueType, at: set.range))
            // SET (column1, column2) = (value1, value2)
            case .list(let columnNames):
                // TODO: Names will not be inferred here. Names only handles
                // TODO: one value at a time. Not an array of values.
                let columns = columns(for: columnNames, from: table)
                sub.merge(unify(columns, with: valueType, at: set.range))
            }
        }
        
        if let from = update.from {
            sub.merge(infer(from: from))
        }
        
        if let whereExpr = update.whereExpr {
            sub.merge(infer(where: whereExpr))
        }
        
        let returnType: Type
        if let returning = update.returningClause {
            let (t, s) = infer(returningClause: returning, sourceTable: table)
            returnType = t
            sub.merge(s)
        } else {
            returnType = .row(.empty)
        }
        
        return (returnType, sub)
    }
    
    mutating func infer(delete: DeleteStmtSyntax) -> (Type, Substitution) {
        var sub: Substitution = [:]
        
        if let cte = delete.cte {
            sub.merge(infer(cte: cte))
        }
        
        guard let table = schema[delete.table.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(delete.table.tableName.name))
            return (.error, sub)
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        if let whereExpr = delete.whereExpr {
            sub.merge(infer(where: whereExpr))
        }
        
        let returnType: Type
        if let returning = delete.returningClause {
            let (t, s) = infer(returningClause: returning, sourceTable: table)
            returnType = t
            sub.merge(s)
        } else {
            returnType = .row(.empty)
        }
        
        return (returnType, sub)
    }
    
    private mutating func columns(
        for names: [IdentifierSyntax],
        from table: Table
    ) -> Type {
        var columns: Columns = [:]
        
        for name in names {
            if let column = table.columns[name.value] {
                columns[name.value] = column
            } else {
                diagnostics.add(.columnDoesNotExist(name))
                columns[name.value] = .error
            }
        }
        
        return .row(.named(columns))
    }
    
    private mutating func infer(
        returningClause: ReturningClauseSyntax,
        sourceTable: Table
    ) -> (Type, Substitution) {
        var resultColumns: Columns = [:]
        var sub: Substitution = [:]
        
        for value in returningClause.values {
            switch value {
            case let .expr(expr, alias):
                let (type, exprSub, names) = expr.accept(visitor: &self)
                sub.merge(exprSub)
                
                guard let name = alias?.value ?? names.proposedName else {
                    diagnostics.add(.nameRequired(at: expr.range))
                    continue
                }
                
                resultColumns[name] = type
            case .all:
                // TODO: See TODO on `Columns` typealias
                resultColumns.merge(sourceTable.columns, uniquingKeysWith: { $1 })
            }
        }
        
        return (.row(.named(resultColumns)), sub)
    }
    
    private mutating func infer(cte: CommonTableExpressionSyntax) -> Substitution {
        let (type, sub) = infer(select: cte.select)

        let tableTy: Type
        if cte.columns.isEmpty {
            tableTy = type
        } else {
            let row = assumeRow(type)
            let columnTypes = row.types
            if columnTypes.count != cte.columns.count {
                diagnostics.add(.init(
                    "CTE expected \(cte.columns.count) columns, but got \(row.count)",
                    at: cte.range
                ))
            }
            
            tableTy = .row(.named(
                (0..<min(columnTypes.count, cte.columns.count))
                    .reduce(into: [:]) { $0[cte.columns[$1].value] = columnTypes[$1] }
            ))
        }
        
        env.insert(cte.table.value, ty: tableTy)
        
        return sub
    }
    
    /// Will infer the core part of the select.
    /// Takes an optional potential names list.
    ///
    /// The select core also includes the `VALUES (?, ?, ?)`
    /// part, and in an insert we want to be able to infer the
    /// parameter names of those.
    /// So on `INSERT INTO foo (bar, baz) VALUES (?, ?)` has
    /// 2 parameters named `bar` and `baz`
    private mutating func infer(
        select: SelectCoreSyntax,
        at range: Range<Substring.Index>,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> (Type, Substitution) {
        switch select {
        case let .select(select):
            return infer(select: select)
        case let .values(groups):
            var sub: Substitution = [:]
            var types: [Type] = []
            
            for values in groups {
                var columns: [Type] = []
                
                for (index, value) in values.enumerated() {
                    let (type, s, names) = value.accept(visitor: &self)
                    sub.merge(s)
                    columns.append(type.apply(sub))
                    
                    // If there are potential names to match with check to
                    // see if there is one at the index of this expression.
                    if let potentialNames, index < potentialNames.count {
                        _ = merge(names: names, with: .some(potentialNames[index].value))
                    }
                }
                
                types.append(.row(.unnamed(columns)))
            }
            
            // All of the different groups, e.g. (1, 2), (3, 4)
            // need to be unified since they are all going into
            // the same columns
            if types.count > 1 {
                sub.merge(unify(all: types, at: range))
            }
            
            return (types.last?.apply(sub) ?? .row(.empty), sub)
        }
    }
    
    private mutating func infer(select: SelectCoreSyntax.Select) -> (Type, Substitution) {
        var sub: Substitution = [:]
        
        if let from = select.from {
            sub.merge(infer(from: from), uniquingKeysWith: { $1 })
        }
        
        let (output, colSub) = infer(resultColumns: select.columns)
        sub.merge(colSub)
        
        if let whereExpr = select.where {
            sub.merge(infer(where: whereExpr), uniquingKeysWith: { $1 })
        }
        
        if let groupBy = select.groupBy {
            for expression in groupBy.expressions {
                _ = expression.accept(visitor: &self)
            }
            
            if let having = groupBy.having {
                let (type, _, _) = having.accept(visitor: &self)
                
                if type != .bool, type != .integer {
                    diagnostics.add(.init(
                        "HAVING clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                        at: having.range
                    ))
                }
            }
        }
        
        return (output, sub)
    }
    
    private mutating func infer(from: FromSyntax) -> Substitution {
        switch from {
        case let .tableOrSubqueries(t):
            var sub: Substitution = [:]
            for table in t {
                sub.merge(infer(table), uniquingKeysWith: { $1 })
            }
            return sub
        case let .join(joinClause):
            return infer(joinClause: joinClause)
        }
    }
    
    private mutating func infer(where expr: ExpressionSyntax) -> Substitution {
        let (type, sub, _) = expr.accept(visitor: &self)
        
        if type != .bool, type != .integer {
            diagnostics.add(.init(
                "WHERE clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                at: expr.range
            ))
        }
        
        return sub
    }
    
    private mutating func infer(resultColumns: [ResultColumnSyntax]) -> (Type, Substitution) {
        var columns: OrderedDictionary<Substring, Type> = [:]
        var sub: Substitution = [:]
        
        for resultColumn in resultColumns {
            switch resultColumn {
            case let .expr(expr, alias):
                let (type, columnSub, names) = expr.accept(visitor: &self)
                sub.merge(columnSub)
                
                if let name = alias?.value ?? names.proposedName {
                    columns[name] = type
                } else {
                    diagnostics.add(.nameRequired(at: expr.range))
                }
            case let .all(tableName):
                if let tableName {
                    if let table = env[tableName.value]?.type {
                        guard case let .row(.named(tableColumns)) = table else {
                            diagnostics.add(.init("'\(tableName)' is not a table", at: tableName.range))
                            continue
                        }
                        
                        for (name, type) in tableColumns {
                            columns[name] = type
                        }
                    } else {
                        diagnostics.add(.init("Table '\(tableName)' does not exist", at: tableName.range))
                    }
                } else {
                    for (name, type) in env {
                        switch type.type {
                        case .row: continue // Ignore tables
                        default: columns[name] = type.type
                        }
                    }
                }
            }
        }
        
        return (.row(.named(columns)), sub)
    }
    
    private mutating func infer(joinClause: JoinClauseSyntax) -> Substitution {
        var sub = infer(joinClause.tableOrSubquery)
        
        for join in joinClause.joins {
            sub.merge(infer(join: join), uniquingKeysWith: { $1 })
        }
        
        return sub
    }
    
    private mutating func infer(join: JoinClauseSyntax.Join) -> Substitution {
        switch join.constraint {
        case let .on(expression):
            let joinSub = infer(join.tableOrSubquery, joinOp: join.op)
            
            let (type, exprSub, _) = expression.accept(visitor: &self)
            
            if type != .bool, type != .integer {
                diagnostics.add(.init(
                    "JOIN clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                    at: expression.range
                ))
            }
            
            return joinSub.merging(exprSub)
        case let .using(columns):
            return infer(
                join.tableOrSubquery,
                joinOp: join.op,
                columns: columns.reduce(into: []) { $0.insert($1.value) }
            )
        case .none:
            return infer(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func infer(
        _ tableOrSubquery: TableOrSubquerySyntax,
        joinOp: JoinOperatorSyntax? = nil,
        columns usedColumns: Set<Substring> = []
    ) -> Substitution {
        switch tableOrSubquery {
        case let .table(table):
            let tableName = TableNameSyntax(schema: table.schema, name: table.name)
            
            guard let envTable = schema[tableName.name.value] else {
                // TODO: Add diag
                env.insert(table.name.value, ty: .error)
                return [:]
            }
            
            let isOptional = switch joinOp {
            case nil, .inner: false
            default: true
            }

            insertTableAndColumnsIntoEnv(
                envTable,
                as: table.alias,
                isOptional: isOptional,
                onlyColumnsIn: usedColumns
            )
            
            return [:]
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            let (type, sub) = inNewEnvironment { inferrer in
                inferrer.infer(select: selectStmt)
            }
            
            // Insert the result of the subquery into the environment
            if let alias {
                env.insert(alias.value, ty: type)
            }
            
            guard case let .row(.named(columns)) = type else {
                fatalError("SELECT did not result a row type")
            }
            
            // Also insert each column into the env. So you dont
            // have to do `alias.column`
            for (name, type) in columns {
                env.insert(name, ty: type)
            }
            
            return sub
        case let .join(joinClause):
            return infer(joinClause: joinClause)
        case .subTableOrSubqueries:
            fatalError()
        }
    }
    
    private func assumeRow(_ ty: Type) -> Type.Row {
        guard case let .row(rowTy) = ty else {
            assertionFailure("This cannot happen")
            return .unnamed([])
        }

        return rowTy
    }
    
    /// Will insert the table and all of its columns into the environment.
    /// Allows queries to access the columns at a top level.
    ///
    /// If `isOptional` is true, all of the column types will be made optional
    /// as well. Useful in joins that may or may not have a match, e.g. Outer
    private mutating func insertTableAndColumnsIntoEnv(
        _ table: Table,
        as alias: IdentifierSyntax? = nil,
        isOptional: Bool = false,
        onlyColumnsIn columns: Set<Substring> = []
    ) {
        env.insert(
            alias?.value ?? table.name,
            ty: isOptional ? .optional(table.type) : table.type
        )
        
        for column in table.columns where columns.isEmpty || columns.contains(column.key) {
            env.insert(column.key, ty: isOptional ? .optional(column.value) : column.value)
        }
    }
}
