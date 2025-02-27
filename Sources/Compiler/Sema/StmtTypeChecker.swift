//
//  StmtTypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections

struct StmtTypeChecker {
    typealias Output = (parameters: [Parameter<Substring?>], output: Type?)
    
    /// The environment in which the query executes. Any joined in tables
    /// will be added to this.
    private(set) var env: Environment
    /// The entire database schema
    private(set) var schema: Schema
    /// Any diagnostics that are emitted during compilation
    private(set) var diagnostics = Diagnostics()
    /// Inferrer for any bind parameter names
    private(set) var nameInferrer = NameInferrer()
    /// The inferernce state for the statement.
    /// We need to hold onto the state for the entire
    /// statement and not have it localized to each expression.
    /// Bind parameters can be used throughout different
    /// expressions in the statement.
    private(set) var inferenceState: InferenceState
    
    private let pragmas: FeatherPragmas
    
    init(
        env: Environment = Environment(),
        schema: Schema,
        inferenceState: InferenceState = InferenceState(),
        pragmas: FeatherPragmas
    ) {
        self.env = env
        self.schema = schema
        self.inferenceState = inferenceState
        self.pragmas = pragmas
    }
    
    /// All diagnostics emitted during type checking of the statement.
    var allDiagnostics: Diagnostics {
        return diagnostics.merging(inferenceState.diagnostics)
    }
    
    /// Calculates the signature for a single expression.
    mutating func signature<E: ExprSyntax>(for expr: E) -> Output {
        let (ty, _) = typeCheck(expr)
        return output(ty: ty)
    }
    
    /// Calculates the solution of an entire statement.
    mutating func signature<S: StmtSyntax>(for stmt: S) -> Output {
        let ty = stmt.accept(visitor: &self)
        return output(ty: ty)
    }
    
    /// Type checks and infers the type and any bind parameter names in the expression
    private mutating func typeCheck<E: ExprSyntax>(_ expr: E) -> (Type, Name) {
        var exprTypeChecker = ExprTypeChecker(
            inferenceState: inferenceState,
            env: env,
            schema: schema,
            pragmas: pragmas
        )
        let type = exprTypeChecker.typeCheck(expr)
        let name = nameInferrer.infer(expr)
        diagnostics.merge(exprTypeChecker.diagnostics)
        // Collect the updated inference state.
        inferenceState = exprTypeChecker.inferenceState
        return (type, name)
    }
    
    /// Calculates the final inferred signature of the statement
    private mutating func output(ty: Type?) -> Output {
        let parameters = inferenceState
            .parameterSolutions(defaultIfTyVar: true)
            .map { parameter in
                Parameter(
                    type: parameter.type,
                    index: parameter.index,
                    name: nameInferrer.parameterName(at: parameter.index)
                )
            }
        
        let type = ty.map { ty in inferenceState.solution(for: ty, defaultIfTyVar: true) }
        
        return (parameters, type)
    }
    
    /// Performs the inference in a new environment.
    /// Useful for subqueries that don't inhereit our current joins.
    private mutating func inNewEnvironment<Output>(
        _ action: (inout StmtTypeChecker) -> Output
    ) -> Output {
        var inferrer = self
        inferrer.env = Environment()
        let result = action(&inferrer)
        diagnostics = inferrer.diagnostics
        nameInferrer = inferrer.nameInferrer
        return result
    }
}

extension StmtTypeChecker: StmtSyntaxVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> Type? {
        typeCheck(createTable: stmt)
        return nil
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> Type? {
        typeCheck(alterTable: stmt)
        return nil
    }
    
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> Type? {
        return typeCheck(select: stmt)
    }
    
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> Type? {
        return typeCheck(insert: stmt)
    }
    
    mutating func visit(_ stmt: borrowing UpdateStmtSyntax) -> Type? {
        return typeCheck(update: stmt)
    }
    
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> Type? {
        return typeCheck(delete: stmt)
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> Type? {
        return nil
    }
    
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> Type? {
        return stmt.statement.accept(visitor: &self)
    }
    
    mutating func visit(_ stmt: borrowing PragmaStmt) -> Type? {
        return nil
    }
    
    mutating func visit(_ stmt: borrowing DropTableStmtSyntax) -> Type? {
        typeCheck(dropTable: stmt)
        return nil
    }
    
    mutating func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> Type? {
        guard let table = schema[stmt.table.value] else {
            diagnostics.add(.tableDoesNotExist(stmt.table))
            return nil
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        if let whereExpr = stmt.whereExpr {
            _ = typeCheck(whereExpr)
        }
        
        return nil
    }
    
    mutating func visit(_ stmt: borrowing DropIndexStmtSyntax) -> Type? {
        // Indices are not stored at the moment, so there is nothign to do.
        return nil
    }
    
    mutating func visit(_ stmt: borrowing ReindexStmtSyntax) -> Type? {
        // Indices are not stored at the moment, so there is nothign to do.
        // We cant really even validate the name since it can be the
        // index name and not just the table
        return nil
    }
    
    mutating func visit(_ stmt: borrowing CreateViewStmtSyntax) -> Type? {
        guard schema[stmt.name.value] == nil else {
            diagnostics.add(.tableAlreadyExists(stmt.name))
            return nil
        }
        
        let select = typeCheck(select: stmt.select)
        let row = assumeRow(select)
    
        if let firstName = stmt.columnNames.first, row.count != stmt.columnNames.count {
            diagnostics.add(.init(
                "SELECT returns \(row.count) columns but only have \(stmt.columnNames.count) names defined",
                at: firstName.range
            ))
        }
        
        let columns: Columns
        if stmt.columnNames.isEmpty {
            guard case let .named(c) = row else {
                diagnostics.add(.init("Column names not defined", at: stmt.range))
                return .error
            }
            
            // Don't have explicit names, just return the column names.
            columns = c
        } else {
            // If the counts do not match a diagnostic will already have been emitted
            // so just for safety choose the minimum of the two.
            let types = row.types
            let minCount = min(stmt.columnNames.count, types.count)
            columns = (0..<minCount).reduce(into: [:]) { columns, index in
                columns[stmt.columnNames[index].value] = types[index]
            }
        }
        
        schema[stmt.name.value] = Table(
            name: stmt.name.value,
            columns: columns,
            primaryKey: [/* In the future we can analyze the select to see if we can do better */],
            kind: .view
        )
        
        return nil
    }
    
    mutating func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> Type? {
        guard schema[stmt.tableName.name.value] == nil else {
            diagnostics.add(.tableAlreadyExists(stmt.tableName.name))
            return nil
        }
        
        switch stmt.module {
        case .fts5:
            typeCheck(fts5Table: stmt)
        case .unknown:
            diagnostics.add(.init("Unknown virtual table module name", at: stmt.moduleName.range))
        }
        
        return nil
    }
}

extension StmtTypeChecker {
    mutating func typeCheck(
        select: SelectStmtSyntax,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> Type {
        if let cte = select.cte?.value {
            typeCheck(cte: cte)
        }
        
        let type = switch select.selects.value {
        case let .single(selectCore):
             typeCheck(
                select: selectCore,
                at: select.range,
                potentialNames: potentialNames
            )
        case .compound:
            fatalError()
        }
        
        for term in select.orderBy {
            _ = typeCheck(term.expr)
        }
        
        if let limit = select.limit {
            _ = typeCheck(limit.expr)
        }
        
        return type
    }
    
    mutating func typeCheck(insert: InsertStmtSyntax) -> Type {
        if let cte = insert.cte {
            typeCheck(cte: cte)
        }
        
        guard let table = schema[insert.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(insert.tableName.name))
            return .error
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
            let type = typeCheck(select: values.select, potentialNames: insert.columns)
            inferenceState.unify(inputType, with: type, at: insert.range)
        } else {
            // TODO: Using 'DEFALUT VALUES' make sure all columns
            // TODO: actually have default values or null
        }
        
        let ty: Type = if let returningClause = insert.returningClause {
            typeCheck(returningClause: returningClause, sourceTable: table)
        } else {
            .row(.empty)
        }
        
        return ty
    }
    
    mutating func typeCheck(update: UpdateStmtSyntax) -> Type {
        if let cte = update.cte {
            typeCheck(cte: cte)
        }
        
        guard let table = schema[update.tableName.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(update.tableName.tableName.name))
            return .error
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        for set in update.sets {
            let (valueType, valueName) = typeCheck(set.expr)
            
            switch set.column {
            // SET column = value
            case let .single(column):
                nameInferrer.suggest(name: column.value, for: valueName)
                
                guard let column = table.columns[column.value] else {
                    diagnostics.add(.columnDoesNotExist(column))
                    return .error
                }
                
                inferenceState.unify(column, with: valueType, at: set.range)
            // SET (column1, column2) = (value1, value2)
            case let .list(columnNames):
                // TODO: Names will not be inferred here. Names only handles
                // TODO: one value at a time. Not an array of values.
                let columns = columns(for: columnNames, from: table)
                inferenceState.unify(columns, with: valueType, at: set.range)
            }
        }
        
        if let from = update.from {
            typeCheck(from: from)
        }
        
        if let whereExpr = update.whereExpr {
            typeCheck(where: whereExpr)
        }
        
        let returnType: Type = if let returning = update.returningClause {
            typeCheck(returningClause: returning, sourceTable: table)
        } else {
            .row(.empty)
        }
        
        return returnType
    }
    
    mutating func typeCheck(delete: DeleteStmtSyntax) -> Type {
        if let cte = delete.cte {
            typeCheck(cte: cte)
        }
        
        guard let table = schema[delete.table.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(delete.table.tableName.name))
            return .error
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        if let whereExpr = delete.whereExpr {
            typeCheck(where: whereExpr)
        }
        
        let returnType: Type = if let returning = delete.returningClause {
            typeCheck(returningClause: returning, sourceTable: table)
        } else {
            .row(.empty)
        }
        
        return returnType
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
    
    private mutating func typeCheck(
        returningClause: ReturningClauseSyntax,
        sourceTable: Table
    ) -> Type {
        var resultColumns: Columns = [:]
        
        for value in returningClause.values {
            switch value {
            case let .expr(expr, alias):
                let (type, names) = typeCheck(expr)
                
                guard let name = alias?.identifier.value ?? names.proposedName else {
                    diagnostics.add(.nameRequired(at: expr.range))
                    continue
                }
                
                resultColumns[name] = type
            case .all:
                // TODO: See TODO on `Columns` typealias
                resultColumns.merge(sourceTable.columns, uniquingKeysWith: { $1 })
            }
        }
        
        return .row(.named(resultColumns))
    }
    
    private mutating func typeCheck(cte: CommonTableExpressionSyntax) {
        let type = typeCheck(select: cte.select)

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
                (0 ..< min(columnTypes.count, cte.columns.count))
                    .reduce(into: [:]) { $0[cte.columns[$1].value] = columnTypes[$1] }
            ))
        }
        
        env.insert(cte.table.value, ty: tableTy)
    }
    
    /// Will infer the core part of the select.
    /// Takes an optional potential names list.
    ///
    /// The select core also includes the `VALUES (?, ?, ?)`
    /// part, and in an insert we want to be able to infer the
    /// parameter names of those.
    /// So on `INSERT INTO foo (bar, baz) VALUES (?, ?)` has
    /// 2 parameters named `bar` and `baz`
    private mutating func typeCheck(
        select: SelectCoreSyntax,
        at range: Range<Substring.Index>,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> Type {
        switch select {
        case let .select(select):
            return typeCheck(select: select)
        case let .values(groups):
            var types: [Type] = []
            
            for values in groups {
                var columns: [Type] = []
                
                for (index, value) in values.enumerated() {
                    let (type, name) = typeCheck(value)
                    columns.append(type)
                    
                    // If there are potential names to match with check to
                    // see if there is one at the index of this expression.
                    if let potentialNames, index < potentialNames.count {
                        nameInferrer.suggest(name: potentialNames[index].value, for: name)
                    }
                }
                
                types.append(.row(.unnamed(columns)))
            }
            
            // All of the different groups, e.g. (1, 2), (3, 4)
            // need to be unified since they are all going into
            // the same columns
            if types.count > 1 {
                inferenceState.unify(all: types, at: range)
            }
            
            return types.last.map { inferenceState.solution(for: $0) } ?? .row(.empty)
        }
    }
    
    private mutating func typeCheck(select: SelectCoreSyntax.Select) -> Type {
        if let from = select.from {
            typeCheck(from: from)
        }
        
        let output = typeCheck(resultColumns: select.columns)

        if let whereExpr = select.where {
            typeCheck(where: whereExpr)
        }
        
        if let groupBy = select.groupBy {
            for expression in groupBy.expressions {
                _ = typeCheck(expression)
            }
            
            if let having = groupBy.having {
                let (type, _) = typeCheck(having)
                
                if type != .bool, type != .integer {
                    diagnostics.add(.init(
                        "HAVING clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                        at: having.range
                    ))
                }
            }
        }
        
        return output
    }
    
    private mutating func typeCheck(from: FromSyntax) {
        switch from {
        case let .tableOrSubqueries(t):
            for table in t {
                typeCheck(table)
            }
        case let .join(joinClause):
            typeCheck(joinClause: joinClause)
        }
    }
    
    private mutating func typeCheck(where expr: ExpressionSyntax) {
        let (type, _) = typeCheck(expr)
        
        if type != .bool, type != .integer {
            diagnostics.add(.init(
                "WHERE clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                at: expr.range
            ))
        }
    }
    
    private mutating func typeCheck(resultColumns: [ResultColumnSyntax]) -> Type {
        var columns: OrderedDictionary<Substring, Type> = [:]
        
        for resultColumn in resultColumns {
            switch resultColumn.kind {
            case let .expr(expr, alias):
                let (type, names) = typeCheck(expr)
                
                if let name = alias?.identifier.value ?? names.proposedName {
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
                        switch type {
                        case .row: continue // Ignore tables
                        default: columns[name] = type
                        }
                    }
                }
            }
        }
        
        return .row(.named(columns))
    }
    
    private mutating func typeCheck(joinClause: JoinClauseSyntax) {
        typeCheck(joinClause.tableOrSubquery)
        
        for join in joinClause.joins {
            typeCheck(join: join)
        }
    }
    
    private mutating func typeCheck(join: JoinClauseSyntax.Join) {
        switch join.constraint.kind {
        case let .on(expression):
            typeCheck(join.tableOrSubquery, joinOp: join.op)
            
            let (type, _) = typeCheck(expression)
            
            if type != .bool, type != .integer {
                diagnostics.add(.init(
                    "JOIN clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                    at: expression.range
                ))
            }
        case let .using(columns):
            typeCheck(
                join.tableOrSubquery,
                joinOp: join.op,
                columns: columns.reduce(into: []) { $0.insert($1.value) }
            )
        case .none:
            typeCheck(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func typeCheck(
        _ tableOrSubquery: TableOrSubquerySyntax,
        joinOp: JoinOperatorSyntax? = nil,
        columns usedColumns: Set<Substring> = []
    ) {
        switch tableOrSubquery.kind {
        case let .table(table):
            guard let envTable = schema[table.name.value] else {
                env.insert(table.name.value, ty: .error)
                diagnostics.add(.tableDoesNotExist(table.name))
                return
            }
            
            let isOptional = switch joinOp?.kind {
            case nil, .inner: false
            default: true
            }

            insertTableAndColumnsIntoEnv(
                envTable,
                as: table.alias,
                isOptional: isOptional,
                onlyColumnsIn: usedColumns
            )
            
            return
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            let type = inNewEnvironment { inferrer in
                inferrer.typeCheck(select: selectStmt)
            }
            
            // Insert the result of the subquery into the environment
            if let alias {
                env.insert(alias.identifier.value, ty: type)
            }
            
            guard case let .row(.named(columns)) = type else {
                fatalError("SELECT did not result a row type")
            }
            
            // Also insert each column into the env. So you dont
            // have to do `alias.column`
            for (name, type) in columns {
                env.insert(name, ty: type)
            }
        case let .join(joinClause):
            typeCheck(joinClause: joinClause)
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
        as alias: AliasSyntax? = nil,
        isOptional: Bool = false,
        onlyColumnsIn columns: Set<Substring> = []
    ) {
        env.insert(
            alias?.identifier.value ?? table.name,
            ty: isOptional ? .optional(table.type) : table.type
        )
        
        for column in table.columns where columns.isEmpty || columns.contains(column.key) {
            env.insert(column.key, ty: isOptional ? .optional(column.value) : column.value)
        }
        
        // Make rank available, but only via by direct name so it isnt
        // included in the result columns during a `SELECT *`
        if table.kind == .fts5 {
            env.insert("rank", ty: .real, explicitAccessOnly: true)
        }
    }
    
    mutating func typeCheck(createTable: CreateTableStmtSyntax) {
        if pragmas.contains(.requireStrictTables)
            && !createTable.options.kind.contains(.strict) {
            diagnostics.add(.init(
                "Missing STRICT table option",
                at: createTable.range,
                suggestion: .append(" STRICT")
            ))
        }
        
        switch createTable.kind {
        case let .select(selectStmt):
            let signature = signature(for: selectStmt)
            
            guard case let .row(row) = signature.output else {
                fatalError("SELECT returned a non row type?")
            }
            
            let columns: Columns
            switch row {
            case .named(let c):
                columns = c
            case .unnamed(let types):
                // Technically this is allowed by SQLite, but the names are auto named `column1...`.
                // I don't think this is a good practice so might as well just error for now.
                // Can be accomplished by doing `CREATE TABLE foo AS VALUES (1, 2, 3);`
                diagnostics.add(.init("Result of SELECT did not have named columns", at: selectStmt.range))
                columns = types.enumerated().reduce(into: [:], { $0["column\($1.offset + 1)"] = $1.element })
            case .unknown(let type):
                // `unknown` is only used in inference, but might as well just set it
                columns = ["column1": type]
            }
            
            schema[createTable.name.value] = Table(
                name: createTable.name.value,
                columns: columns,
                primaryKey: primaryKey(of: createTable, columns: columns),
                kind: .normal
            )
        case let .columns(columns):
            let columns: Columns = columns.reduce(into: [:]) {
                $0[$1.value.name.value] = typeFor(column: $1.value)
            }
            
            schema[createTable.name.value] = Table(
                name: createTable.name.value,
                columns: columns,
                primaryKey: primaryKey(of: createTable, columns: columns),
                kind: .normal
            )
        }
    }
    
    mutating func typeCheck(alterTable: AlterTableStmtSyntax) {
        guard var table = schema[alterTable.name.value] else {
            diagnostics.add(.tableDoesNotExist(alterTable.name))
            return
        }

        switch table.kind {
        case .fts5:
            diagnostics.add(.init("Cannot alter virtual table", at: alterTable.name.range))
            return
        case .view:
            diagnostics.add(.init("Cannot alter view", at: alterTable.name.range))
            return
        default:
            break
        }
        
        switch alterTable.kind {
        case let .rename(newName):
            schema[alterTable.name.value] = nil
            schema[newName.value] = table
        case let .renameColumn(oldName, newName):
            table.columns = table.columns.reduce(into: [:]) { newColumns, column in
                newColumns[column.key == oldName.value ? newName.value : column.key] = column.value
            }
        case let .addColumn(column):
            table.columns[column.name.value] = typeFor(column: column)
        case let .dropColumn(column):
            table.columns[column.value] = nil
        }
        
        schema[alterTable.name.value] = table
    }
    
    mutating func typeCheck(dropTable: DropTableStmtSyntax) {
        let tableExists = schema[dropTable.tableName.name.value] != nil
        
        if !tableExists && !dropTable.ifExists {
            diagnostics.add(.tableDoesNotExist(dropTable.tableName.name))
        }
        
        schema[dropTable.tableName.name.value] = nil
    }
    
    /// Will figure out the final SQL column type from the syntax
    private func typeFor(column: borrowing ColumnDefSyntax) -> Type {
        // Technically you can have a NULL primary key but I don't
        // think people actually do that...
        let isNotNullable = column.constraints
            .contains { $0.isPkConstraint || $0.isNotNullConstraint }
        
        let nominal: Type = .nominal(column.type.name.value)
        
        let type: Type = if let alias = column.type.alias {
            .alias(nominal, alias.identifier.value)
        } else {
            nominal
        }
        
        if isNotNullable {
            return type
        } else {
            return .optional(type)
        }
    }
    
    /// Gets the column names of the primary key and validates them
    private mutating func primaryKey(
        of stmt: CreateTableStmtSyntax,
        columns: Columns
    ) -> [Substring] {
        // Any PK define by table constraints
        let byTableConstraints: [([IndexedColumnSyntax], TableConstraintSyntax)] = stmt.constraints
            .compactMap { constraint -> ([IndexedColumnSyntax], TableConstraintSyntax)? in
                guard case let .primaryKey(columns, _) = constraint.kind else { return nil }
                return (columns, constraint)
            }
        
        // Any PK defined at the column level
        let byColumnConstraints: [IdentifierSyntax]
        if case let .columns(columns) = stmt.kind {
            byColumnConstraints = columns.values
                .filter{ $0.constraints.contains(where: \.isPkConstraint) }
                .map(\.name)
        } else {
            // Due to parsing this should never be allowed to happen but easy to check
            if let constraint = byTableConstraints.first {
                diagnostics.add(.init(
                    "CREATE TABLE AS SELECT cannot have any constraints",
                    at: constraint.1.range
                ))
            }
            
            return []
        }
        
        // Make sure only 1 primary key constraint is added.
        // This allows for PRIMARY KEY(foo, bar) but not for multiple of those constraints
        if !byColumnConstraints.isEmpty, let constraint = byTableConstraints.first {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.1.range))
        } else if byColumnConstraints.count > 1, let constraint = byColumnConstraints.last {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.range))
        } else if byTableConstraints.count > 1, let constraint = byTableConstraints.last {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.1.range))
        }
        
        if !byColumnConstraints.isEmpty && byTableConstraints.isEmpty {
            return byColumnConstraints.map(\.value)
        } else {
            // Make sure the columns actually exist since they are define afterwards
            var columnNames: [Substring] = []
            for constraint in byTableConstraints {
                for column in constraint.0 {
                    guard let name = column.columnName else { continue }
                    
                    if columns[name.value] == nil {
                        diagnostics.add(.columnDoesNotExist(name))
                    } else {
                        columnNames.append(name.value)
                    }
                }
            }
            return columnNames
        }
    }
    
    mutating func typeCheck(fts5Table: borrowing CreateVirtualTableStmtSyntax) {
        var columns: Columns = [:]
        
        for argument in fts5Table.arguments {
            switch argument {
            case let .fts5Column(name, typeName, notNull, _):
                guard let typeName = typeName?.name.value else {
                    diagnostics.add(.init("Missing column type", at: name.range))
                    continue
                }
                
                columns[name.value] = notNull != nil
                    ? .nominal(typeName)
                    : .optional(.nominal(typeName))
            case .fts5Option:
                break // Nothing to do, maybe validate these in the future
            case .unknown:
                fatalError("Not FTS5, caller did not call the right method")
            }
        }
        
        schema[fts5Table.tableName.name.value] = Table(
            name: fts5Table.tableName.name.value,
            columns: columns,
            primaryKey: [],
            kind: .fts5
        )
    }
}
