//
//  TypeInferrer.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections

struct Solution {
    let diagnostics: Diagnostics
    let signature: Signature
    let lastName: Substring?
    
    var type: Ty? {
        return signature.output
    }
    
    func type(for index: Int) -> Ty? {
        return signature.parameters[index]?.type
    }
    
    func type(for name: Substring) -> Ty? {
        guard let (index, _) = signature.parameters
            .first(where: { $1.name == name }) else { return nil }
        
        return type(for: index)
    }
    
    func name(for index: Int) -> Substring? {
        return signature.parameters[index]?.name
    }
}

struct InferenceState {
    let type: Ty
    let substitution: Substitution
    let names: Names
}

struct TypeInferrer {
    /// The environment in which the query executes. Any joined in tables
    /// will be added to this.
    private var env: Environment
    private let schema: Schema
    private var diagnostics: Diagnostics
    private var tyVars = 0
    private var parameterTypes: [BindParameter.Index: Ty] = [:]
    private var constraints: Constraints = [:]
    /// We are not only inferring types but potential names for the parameters.
    /// Any result will be added here
    private var parameterNames: [BindParameter.Index: Substring] = [:]
    
    private static let missingNameDefault: Substring = "__name_required__"
    
    init(
        env: Environment,
        schema: Schema,
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.env = env
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    mutating func check<E: Expr>(_ expr: E) -> Solution {
        let (ty, sub, names) = expr.accept(visitor: &self)
        return finalize(ty: ty, sub: sub, names: names)
    }
    
    mutating func solution<S: Stmt>(for stmt: S) -> Solution {
        let (ty, sub) = stmt.accept(visitor: &self)
        return finalize(ty: ty, sub: sub, names: .none)
    }
    
    private mutating func finalize(
        ty: Ty?,
        sub: Substitution,
        names: Names
    ) -> Solution {
        let constraints = finalizeConstraints(with: sub)
        
        let signature = Signature(
            parameters: parameterTypes.reduce(into: [:]) { params, value in
                params[value.key] = Parameter(
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
            }
        )
        
        return Solution(
            diagnostics: diagnostics,
            signature: signature,
            lastName: names.proposedName
        )
    }
    
    private func finalType(
        for ty: Ty,
        substitution: Substitution,
        constraints: Constraints
    ) -> Ty {
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
    
    private mutating func finalizeConstraints(
        with substitution: Substitution
    ) -> Constraints {
        var result: [TypeVariable: TypeConstraints] = [:]
        
        for (tv, constraints) in constraints {
            let ty = Ty.var(tv).apply(substitution)
            
            if case let .var(tv) = ty {
                result[tv] = constraints
            } else {
                // TODO: If it is a non type variable we need to validate
                // the type meets the constraints requirements.
            }
        }
        
        return result
    }
    
    private mutating func freshTyVar(for param: BindParameter? = nil) -> TypeVariable {
        defer { tyVars += 1 }
        let ty = TypeVariable(tyVars)
        if let param {
            parameterTypes[param.index] = .var(ty)
        }
        return ty
    }
    
    private mutating func instantiate(_ typeScheme: TypeScheme) -> Ty {
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
        _ ty: Ty,
        with other: Ty,
        at range: Range<String.Index>
    ) -> Substitution {
        ty.unify(with: other, at: range, diagnostics: &diagnostics)
    }
    
    private mutating func unify(
        all tys: [Ty],
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
        for index: BindParameter.Index
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
        tyVars = inferrer.tyVars
        parameterTypes = inferrer.parameterTypes
        constraints = inferrer.constraints
        return result
    }
}

extension TypeInferrer: ExprVisitor {
    mutating func visit(_ expr: borrowing LiteralExpr) -> (Ty, Substitution, Names) {
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
    
    mutating func visit(_ expr: borrowing BindParameter) -> (Ty, Substitution, Names) {
        let expr = copy expr
        let names: Names
        switch expr.kind {
        case .named(let name):
            track(name: name.value, for: expr.index)
            names = .none
        case .unnamed:
            names = .needed(index: expr.index)
        }
        
        return (.var(freshTyVar(for: expr)), [:], names)
    }
    
    mutating func visit(_ expr: borrowing ColumnExpr) -> (Ty, Substitution, Names) {
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
    
    mutating func visit(_ expr: borrowing PrefixExpr) -> (Ty, Substitution, Names) {
        let (t, s, n) = expr.rhs.accept(visitor: &self)
        
        guard let scheme = env[prefix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid prefix operator",
                at: expr.operator.range
            ))
            return (.error, s, n)
        }
        
        let tv: Ty = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [t], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(s), n)
    }
    
    mutating func visit(_ expr: borrowing InfixExpr) -> (Ty, Substitution, Names) {
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
        
        let tv: Ty = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [lTy.apply(rSub), rTy], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(rSub, lSub), names)
    }
    
    mutating func visit(_ expr: borrowing PostfixExpr) -> (Ty, Substitution, Names) {
        let (t, s, n) = expr.lhs.accept(visitor: &self)
        
        guard let scheme = env[postfix: expr.operator.operator] else {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid postfix operator",
                at: expr.operator.range
            ))
            return (.error, s, n)
        }
        
        let tv: Ty = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [t], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(s), n)
    }
    
    mutating func visit(_ expr: borrowing BetweenExpr) -> (Ty, Substitution, Names) {
        let (tys, sub, names) = visit(many: [expr.value, expr.lower, expr.upper])
        let betSub = unify(instantiate(Builtins.between), with: .fn(params: tys, ret: .bool), at: expr.range)
        return (.bool, betSub.merging(sub), names)
    }
    
    mutating func visit(_ expr: borrowing FunctionExpr) -> (Ty, Substitution, Names) {
        let (argTys, argSub, argNames) = visit(many: expr.args)
        
        guard let scheme = env[function: expr.name.value, argCount: argTys.count] else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.range))
            return (.error, argSub, argNames)
        }
        
        let tv: Ty = .var(freshTyVar())
        let sub = unify(instantiate(scheme), with: .fn(params: argTys, ret: tv), at: expr.range)
        return (tv, sub.merging(argSub), argNames)
    }
    
    mutating func visit(_ expr: borrowing CastExpr) -> (Ty, Substitution, Names) {
        let (_, s, n) = expr.expr.accept(visitor: &self)
        return (.nominal(expr.ty.name.value), s, n)
    }
    
    mutating func visit(_ expr: borrowing Expression) -> (Ty, Substitution, Names) {
        fatalError("TODO: Clean this up. Should never get called. It's `accept` calls the wrapped method, not this")
    }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExpr) -> (Ty, Substitution, Names) {
        let ret: Ty = .var(freshTyVar())
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
    
    mutating func visit(_ expr: borrowing GroupedExpr) -> (Ty, Substitution, Names) {
        let (t, s, n) = visit(many: expr.exprs)
        return (.row(.unnamed(t)), s, n)
    }
    
    mutating func visit(_ expr: borrowing SelectExpr) -> (Ty, Substitution, Names) {
        let (ty, sub) = compile(select: expr.select)
        return (ty, sub, .none)
    }
    
    func visit(_ expr: borrowing InvalidExpr) -> (Ty, Substitution, Names) {
        return (.error, [:], .none)
    }
    
    private mutating func visit(many exprs: [Expression]) -> ([Ty], Substitution, Names) {
        var tys: [Ty] = []
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


extension TypeInferrer: StmtVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmt) -> (Ty?, Substitution) {
        fatalError()
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmt) -> (Ty?, Substitution) {
        fatalError()
    }
    
    mutating func visit(_ stmt: borrowing SelectStmt) -> (Ty?, Substitution) {
        return compile(select: stmt)
    }
    
    mutating func visit(_ stmt: borrowing InsertStmt) -> (Ty?, Substitution) {
        return compile(insert: stmt)
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmt) -> (Ty?, Substitution) {
        return (nil, [:])
    }
}

extension TypeInferrer {
    mutating func compile(select: SelectStmt) -> (Ty, Substitution) {
        var sub: Substitution = [:]
        
        if let cte = select.cte?.value {
            sub.merge(compile(cte: cte))
        }
        
        switch select.selects.value {
        case let .single(select):
            let (type, selectSub) = compile(select: select)
            sub.merge(selectSub)
            return (type, sub)
        case .compound:
            fatalError()
        }
    }
    
    mutating func compile(insert: InsertStmt) -> (Ty, Substitution) {
        var sub: Substitution = [:]
        
        if let cte = insert.cte {
            sub.merge(compile(cte: cte))
        }
        
        guard let table = schema[insert.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(insert.tableName.name))
            return (.error, sub)
        }
        
        let inputType: Ty
        if let columns = insert.columns {
            var columnTypes: [Ty] = []
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
            let (type, selectSub) = compile(select: values.select)
            sub.merge(selectSub)
            _ = inputType.unify(with: type, at: insert.range, diagnostics: &diagnostics)
        } else {
            // TODO: Using 'DEFALUT VALUES' make sure all columns
            // TODO: actually have default values or null
        }
        
        let (ty, retSub): (Ty, Substitution) = if let returningClause = insert.returningClause {
            compile(returningClause: returningClause, sourceTable: table)
        } else {
            (.row(.empty), [:])
        }
        
        sub.merge(retSub)
        return (ty, sub)
    }
    
    private mutating func compile(
        returningClause: ReturningClause,
        sourceTable: CompiledTable
    ) -> (Ty, Substitution) {
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
                resultColumns.merge(resultColumns, uniquingKeysWith: { $1 })
            }
        }
        
        return (.row(.named(resultColumns)), sub)
    }
    
    private mutating func compile(cte: CommonTableExpression) -> Substitution {
        let (type, sub) = compile(select: cte.select)

        let tableTy: Ty
        if cte.columns.isEmpty {
            tableTy = type
        } else {
            guard case let .row(row) = type else {
                assertionFailure("Select is not a row?")
                return sub
            }
            
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
    
    private mutating func compile(select: SelectCore) -> (Ty, Substitution) {
        switch select {
        case let .select(select):
            return compile(select: select)
        case let .values(values):
            var sub: Substitution = [:]
            var types: [Ty] = []
            
            for value in values {
                let (type, s, _) = value.accept(visitor: &self)
                sub.merge(s, uniquingKeysWith: {$1})
                types.append(type)
            }
            
            return (.row(.unnamed(types)), sub)
        }
    }
    
    private mutating func compile(select: SelectCore.Select) -> (Ty, Substitution) {
        var sub: Substitution = [:]
        
        if let from = select.from {
            sub.merge(compile(from: from), uniquingKeysWith: {$1})
        }
        
        let (output, colSub) = compile(resultColumns: select.columns)
        sub.merge(colSub)
        
        if let whereExpr = select.where {
            sub.merge(compile(where: whereExpr), uniquingKeysWith: {$1})
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
    
    private mutating func compile(from: From) -> Substitution {
        switch from {
        case let .tableOrSubqueries(t):
            var sub: Substitution = [:]
            for table in t {
                sub.merge(compile(table), uniquingKeysWith: {$1})
            }
            return sub
        case let .join(joinClause):
            return compile(joinClause: joinClause)
        }
    }
    
    private mutating func compile(where expr: Expression) -> Substitution {
        let (type, sub, _) = expr.accept(visitor: &self)
        
        if type != .bool, type != .integer {
            diagnostics.add(.init(
                "WHERE clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                at: expr.range
            ))
        }
        
        return sub
    }
    
    private mutating func compile(resultColumns: [ResultColumn]) -> (Ty, Substitution) {
        var columns: OrderedDictionary<Substring, Ty> = [:]
        var sub: Substitution = [:]
        
        for resultColumn in resultColumns {
            switch resultColumn {
            case let .expr(expr, alias):
                let (type, columnSub, names) = expr.accept(visitor: &self)
                sub.merge(columnSub)
                
                let name = alias?.value ?? names.proposedName
                columns[name ?? TypeInferrer.missingNameDefault] = type
                
                if name == nil {
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
    
    private mutating func compile(joinClause: JoinClause) -> Substitution {
        var sub = compile(joinClause.tableOrSubquery)
        
        for join in joinClause.joins {
            sub.merge(compile(join: join), uniquingKeysWith: {$1})
        }
        
        return sub
    }
    
    private mutating func compile(join: JoinClause.Join) -> Substitution {
        switch join.constraint {
        case let .on(expression):
            let joinSub = compile(join.tableOrSubquery, joinOp: join.op)
            
            let (type, exprSub, _) = expression.accept(visitor: &self)
            
            if type != .bool, type != .integer {
                diagnostics.add(.init(
                    "JOIN clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                    at: expression.range
                ))
            }
            
            return joinSub.merging(exprSub)
        case let .using(columns):
            return compile(
                join.tableOrSubquery,
                joinOp: join.op,
                columns: columns.reduce(into: []) { $0.insert($1.value) }
            )
        case .none:
            return compile(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func compile(
        _ tableOrSubquery: TableOrSubquery,
        joinOp: JoinOperator? = nil,
        columns usedColumns: Set<Substring> = []
    ) -> Substitution {
        switch tableOrSubquery {
        case let .table(table):
            let tableName = TableName(schema: table.schema, name: table.name)
            
            guard let envTable = schema[tableName.name.value] else {
                // TODO: Add diag
                env.insert(table.name.value, ty: .error)
                return [:]
            }
            
            let isOptional = switch joinOp {
            case nil, .inner: false
            default: true
            }

            env.insert(
                table.alias?.value ?? table.name.value,
                ty: isOptional ? .optional(envTable.type) : envTable.type
            )
            
            for column in envTable.columns where usedColumns.isEmpty || usedColumns.contains(column.key) {
                env.insert(column.key, ty: isOptional ? .optional(column.value) : column.value)
            }
            
            return [:]
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            let (type, sub) = inNewEnvironment { inferrer in
                inferrer.compile(select: selectStmt)
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
            return compile(joinClause: joinClause)
        case .subTableOrSubqueries:
            fatalError()
        }
    }
    
    private func assumeRow(_ ty: Ty) -> Ty.RowTy {
        guard case let .row(rowTy) = ty else {
            assertionFailure("This cannot happen")
            return .unnamed([])
        }

        return rowTy
    }
}
