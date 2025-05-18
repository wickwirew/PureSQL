//
//  StmtTypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections

struct StmtTypeChecker {
    typealias Signature = (parameters: [Parameter<Substring?>], output: ResultColumns)
    
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
    /// Any table that the statement used. This is the table's actual name
    /// not any alias that may have been set.
    /// Its a `Set` to not bring in duplicates
    private(set) var usedTableNames: Set<Substring> = []
    
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

    /// Calculates the solution of an entire statement.
    mutating func signature<S: StmtSyntax>(for stmt: S) -> Signature {
        let resultColumns = stmt.accept(visitor: &self)
        return output(resultColumns: resultColumns)
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
        usedTableNames.formUnion(exprTypeChecker.usedTableNames)
        return (type, name)
    }
    
    /// Calculates the final inferred signature of the statement
    private mutating func output(resultColumns: ResultColumns) -> Signature {
        let parameters = inferenceState
            .parameterSolutions(defaultIfTyVar: true)
            .map { parameter in
                Parameter(
                    type: parameter.type,
                    index: parameter.index,
                    name: nameInferrer.parameterName(at: parameter.index),
                    locations: parameter.locations
                )
            }
        
        return (
            parameters,
            resultColumns.mapTypes { ty in
                inferenceState.solution(for: ty, defaultIfTyVar: true)
            }
        )
    }
    
    /// Performs the inference in a new environment.
    /// Useful for subqueries that don't inhereit our current joins.
    private mutating func inNewEnvironment<Output>(
        extendCurrentEnv: Bool = false,
        _ action: (inout StmtTypeChecker) -> Output
    ) -> Output {
        var inferrer = self
        
        if !extendCurrentEnv {
            inferrer.env = Environment()
        }
        
        let result = action(&inferrer)
        diagnostics = inferrer.diagnostics
        nameInferrer = inferrer.nameInferrer
        inferenceState = inferrer.inferenceState
        usedTableNames.formUnion(inferrer.usedTableNames)
        return result
    }
}

extension StmtTypeChecker: StmtSyntaxVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> ResultColumns {
        typeCheck(createTable: stmt)
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> ResultColumns {
        typeCheck(alterTable: stmt)
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> ResultColumns {
        return typeCheck(select: stmt)
    }
    
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> ResultColumns {
        return typeCheck(insert: stmt)
    }
    
    mutating func visit(_ stmt: borrowing UpdateStmtSyntax) -> ResultColumns {
        return typeCheck(update: stmt)
    }
    
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> ResultColumns {
        return typeCheck(delete: stmt)
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> ResultColumns {
        return stmt.statement.accept(visitor: &self)
    }
    
    mutating func visit(_ stmt: borrowing PragmaStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing DropTableStmtSyntax) -> ResultColumns {
        typeCheck(dropTable: stmt)
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> ResultColumns {
        guard let table = schema[stmt.table.value] else {
            diagnostics.add(.tableDoesNotExist(stmt.table))
            return .empty
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        if let whereExpr = stmt.whereExpr {
            _ = typeCheck(whereExpr)
        }
        
        schema[index: stmt.name.value] = Index(
            name: stmt.name.value,
            table: table.name
        )
        
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing DropIndexStmtSyntax) -> ResultColumns {
        if !stmt.ifExists, schema[index: stmt.name.value] == nil {
            diagnostics.add(.init("Index does not exist", at: stmt.name.location))
        }
        
        schema[index: stmt.name.value] = nil
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing ReindexStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing CreateViewStmtSyntax) -> ResultColumns {
        guard schema[stmt.name.value] == nil else {
            diagnostics.add(.tableAlreadyExists(stmt.name))
            return .empty
        }
        
        let select = typeCheck(select: stmt.select)
        let resultColumns = select.allColumns
        
        if let firstName = stmt.columnNames.first, resultColumns.count != stmt.columnNames.count {
            diagnostics.add(.init(
                "SELECT returns \(resultColumns.count) columns but only have \(stmt.columnNames.count) names defined",
                at: firstName.location
            ))
        }
        
        let columns: Columns
        if stmt.columnNames.isEmpty {
            // Don't have explicit names, just return the column names.
            columns = resultColumns
        } else {
            // If the counts do not match a diagnostic will already have been emitted
            // so just for safety choose the minimum of the two.
            let types = resultColumns.values
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
        
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing DropViewStmtSyntax) -> ResultColumns {
        guard let table = schema[stmt.viewName.value] else {
            if !stmt.ifExists {
                diagnostics.add(.init("View with name does not exist", at: stmt.viewName.location))
            }
            return .empty
        }
        
        if table.kind != .view {
            diagnostics.add(.init("Table is not a view", at: stmt.viewName.location))
        }
        
        schema[stmt.viewName.value] = nil
        
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> ResultColumns {
        if !stmt.ifNotExists, schema[stmt.tableName.name.value] != nil {
            diagnostics.add(.tableAlreadyExists(stmt.tableName.name))
        }
        
        switch stmt.module {
        case .fts5:
            typeCheck(fts5Table: stmt)
        case .unknown:
            diagnostics.add(.init("Unknown virtual table module name", at: stmt.moduleName.location))
        }
        
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing CreateTriggerStmtSyntax) -> ResultColumns {
        guard let table = schema[stmt.tableName.value] else {
            diagnostics.add(.tableDoesNotExist(stmt.tableName))
            return .empty
        }
        
        if !stmt.ifNotExists, schema[trigger: stmt.triggerName.value] != nil {
            diagnostics.add(.init(
                "Trigger with name already exists",
                at: stmt.triggerName.location
            ))
        }
        
        switch stmt.action {
        case .delete:
            insertTableAndColumnsIntoEnv(table, as: "old", globallyAddColumns: false)
        case .insert:
            insertTableAndColumnsIntoEnv(table, as: "new", globallyAddColumns: false)
        case let .update(columns):
            insertTableAndColumnsIntoEnv(table, as: "new", globallyAddColumns: false)
            insertTableAndColumnsIntoEnv(table, as: "old", globallyAddColumns: false)
            
            // Make sure all columns in the update statement actually exist
            if let columns {
                for column in columns {
                    if table.columns[column.value] == nil {
                        diagnostics.add(.columnDoesNotExist(column))
                    }
                }
            }
        }
        
        if let when = stmt.when {
            let (whenType, _) = typeCheck(when)
            
            // Make sure the value is a valid boolean (integer)
            inferenceState.unify(whenType, with: .integer, at: when.location)
        }
        
        for statement in stmt.statements {
            // Extending the current environment to include new/old
            _ = inNewEnvironment(extendCurrentEnv: true) { typeChecker in
                statement.accept(visitor: &typeChecker)
            }
        }
        
        schema[trigger: stmt.triggerName.value] = Trigger(
            name: stmt.triggerName.value,
            targetTable: table.name,
            usedTables: usedTableNames.subtracting([table.name])
        )
        
        return .empty
    }
    
    mutating func visit(_ stmt: borrowing DropTriggerStmtSyntax) -> ResultColumns {
        if !stmt.ifExists, schema[trigger: stmt.triggerName.value] == nil {
            diagnostics.add(.init("Trigger with name does not exist", at: stmt.triggerName.location))
        }
        
        schema[trigger: stmt.triggerName.value] = nil
        return .empty
    }
}

extension StmtTypeChecker {
    mutating func typeCheck(
        select: SelectStmtSyntax,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> ResultColumns {
        if let cte = select.cte?.value {
            typeCheck(cte: cte)
        }
        
        let resultColumns = typeCheck(
            selects: select.selects.value,
            at: select.location,
            potentialNames: potentialNames
        )
        
        for term in select.orderBy {
            _ = typeCheck(term.expr)
        }
        
        if let limit = select.limit {
            _ = typeCheck(limit.expr)
        }
        
        return resultColumns
    }
    
    mutating func typeCheck(
        selects: SelectStmtSyntax.Selects,
        at location: SourceLocation,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> ResultColumns {
        switch selects {
        case let .single(selectCore):
            return typeCheck(
                select: selectCore,
                at: location,
                potentialNames: potentialNames
            )
        case let .compound(first, op, second):
            // SQLite:
            // * Does not care about types
            // * Uses names of first
            // * Cares about # of columns
            
            let firstResult = inNewEnvironment { typeChecker in
                typeChecker.typeCheck(
                    select: first,
                    at: location,
                    potentialNames: potentialNames
                )
            }
            
            let secondResult = inNewEnvironment { typeChecker in
                typeChecker.typeCheck(selects: second, at: location)
            }
            
            guard firstResult.count == secondResult.count else {
                diagnostics.add(.init(
                    "SELECTs for \(op.kind) do not have the same number of columns (\(firstResult.count) and \(secondResult.count))",
                    at: op.location
                ))
                return firstResult
            }
            
            var index = 0
            let secondColumns = secondResult.allColumns.values
            return firstResult.mapTypes { type in
                inferenceState.unify(type, with: secondColumns[index], at: location)
                index += 1
                return type
            }
        }
    }
    
    mutating func typeCheck(insert: InsertStmtSyntax) -> ResultColumns {
        if let cte = insert.cte {
            typeCheck(cte: cte)
        }
        
        guard let table = schema[insert.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(insert.tableName.name))
            return .empty
        }
        
        usedTableNames.insert(table.name)
        
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
            let resultColumns = typeCheck(select: values.select, potentialNames: insert.columns)
            inferenceState.unify(inputType, with: resultColumns.type, at: insert.location)
        } else {
            // TODO: Using 'DEFALUT VALUES' make sure all columns
            // TODO: actually have default values or null
        }
        
        let resultColumns: ResultColumns = if let returningClause = insert.returningClause {
            typeCheck(returningClause: returningClause, sourceTable: table)
        } else {
            .empty
        }
        
        return resultColumns
    }
    
    mutating func typeCheck(update: UpdateStmtSyntax) -> ResultColumns {
        if let cte = update.cte {
            typeCheck(cte: cte)
        }
        
        guard let table = schema[update.tableName.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(update.tableName.tableName.name))
            return .empty
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
                    return .empty
                }
                
                inferenceState.unify(column, with: valueType, at: set.location)
            // SET (column1, column2) = (value1, value2)
            case let .list(columnNames):
                // TODO: Names will not be inferred here. Names only handles
                // TODO: one value at a time. Not an array of values.
                let columns = columns(for: columnNames, from: table)
                inferenceState.unify(columns, with: valueType, at: set.location)
            }
        }
        
        if let from = update.from {
            typeCheck(from: from)
        }
        
        if let whereExpr = update.whereExpr {
            typeCheck(where: whereExpr)
        }
        
        let returnType: ResultColumns = if let returning = update.returningClause {
            typeCheck(returningClause: returning, sourceTable: table)
        } else {
            .empty
        }
        
        return returnType
    }
    
    mutating func typeCheck(delete: DeleteStmtSyntax) -> ResultColumns {
        if let cte = delete.cte {
            typeCheck(cte: cte)
        }
        
        guard let table = schema[delete.table.tableName.name.value] else {
            diagnostics.add(.tableDoesNotExist(delete.table.tableName.name))
            return .empty
        }
        
        insertTableAndColumnsIntoEnv(table)
        
        if let whereExpr = delete.whereExpr {
            typeCheck(where: whereExpr)
        }
        
        let returnType: ResultColumns = if let returning = delete.returningClause {
            typeCheck(returningClause: returning, sourceTable: table)
        } else {
            .empty
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
    ) -> ResultColumns {
        var resultColumns: Columns = [:]
        
        for (offset, value) in returningClause.values.enumerated() {
            switch value {
            case let .expr(expr, alias):
                let (type, names) = typeCheck(expr)
                
                let name = alias?.identifier.value ?? names.proposedName ?? "column\(offset + 1)"
                
                resultColumns[name] = type
            case .all:
                // TODO: See TODO on `Columns` typealias
                resultColumns.merge(sourceTable.columns, uniquingKeysWith: { $1 })
            }
        }
        
        return ResultColumns(columns: resultColumns, table: nil)
    }
    
    private mutating func typeCheck(cte: CommonTableExpressionSyntax) {
        let resultColumns = typeCheck(select: cte.select)

        let columns: Columns
        if cte.columns.isEmpty {
            columns = resultColumns.allColumns
        } else {
            let columnTypes = resultColumns.allColumns.values
            if columnTypes.count != cte.columns.count {
                diagnostics.add(.init(
                    "CTE expected \(cte.columns.count) columns, but got \(columnTypes.count)",
                    at: cte.location
                ))
            }
            
            columns = (0 ..< min(columnTypes.count, cte.columns.count))
                .reduce(into: [:]) { $0[cte.columns[$1].value] = columnTypes[$1] }
        }
        
        env.insert(cte.table.value, ty: .row(.named(columns)))
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
        at range: SourceLocation,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> ResultColumns {
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
            
            guard case let .row(row) = types.last else {
                return ResultColumns(columns: [:], table: nil)
            }
            
            return ResultColumns(
                columns: Columns(
                    withDefaultNames: row.types.map { inferenceState.solution(for: $0) }
                ),
                table: nil
            )
        }
    }
    
    private mutating func typeCheck(select: SelectCoreSyntax.Select) -> ResultColumns {
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
                
                if type != .integer {
                    diagnostics.add(.init(
                        "HAVING clause should return an 'INTEGER', got '\(type)'",
                        at: having.location
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
        
        if type != .integer {
            diagnostics.add(.init(
                "WHERE clause should return an 'INTEGER', got '\(type)'",
                at: expr.location
            ))
        }
    }
    
    private mutating func typeCheck(resultColumns: [ResultColumnSyntax]) -> ResultColumns {
        var columns: OrderedDictionary<Substring, Type> = [:]
        var table: Substring?
        var chunks: [ResultColumns.Chunk] = []
        
        func breakOffCurrentChunkIfNeeded() {
            guard !columns.isEmpty else { return }
            
            let chunk = ResultColumns.Chunk(columns: columns, table: table)
            chunks.append(chunk)
            
            columns = [:]
            table = nil
        }
        
        for (offset, resultColumn) in resultColumns.enumerated() {
            switch resultColumn.kind {
            case let .expr(expr, alias):
                let (type, names) = typeCheck(expr)
                let name = alias?.identifier.value ?? names.proposedName ?? "column\(offset + 1)"
                
                columns[name] = type
                nameInferrer.suggest(name: name, for: names)
                
                // We selected a single column, so clear out the table
                // since its not a select all of a table.
                table = nil
            case let .all(tableName):
                if let tableName {
                    // Was a `table.*`, import every column from the table.
                    if let table = env[tableName.value]?.type {
                        guard case let .row(.named(tableColumns)) = table else {
                            diagnostics.add(.init("'\(tableName)' is not a table", at: tableName.location))
                            continue
                        }
                        
                        // Insert any columns that have been defined before the `table.*`
                        breakOffCurrentChunkIfNeeded()
                        
                        // Add table columns as a chunk
                        chunks.append(ResultColumns.Chunk(
                            columns: tableColumns,
                            table: tableName.value
                        ))
                    } else {
                        diagnostics.add(.init("Table '\(tableName)' does not exist", at: tableName.location))
                    }
                } else {
                    // No table specified so import everything in from the environment.
                    
                    // As we iterate over the environment we will count the number of tables
                    var numberOfTables = 0
                    var lastTable: Substring?
                    let columnsBeforeThis = columns.isEmpty
                    
                    for (name, type) in env {
                        switch type {
                        case .row:
                            lastTable = name
                            numberOfTables += 1
                        default:
                            columns[name] = type
                        }
                    }
                    
                    // If there was only 1 table in the environment, and there were
                    // no columns defined before this `*` then so far we will assume
                    // that the overall result can be mapped to this table.
                    if numberOfTables == 1, columnsBeforeThis {
                        table = lastTable
                    }
                }
            }
        }
        
        // Insert any remaining columns.
        breakOffCurrentChunkIfNeeded()
        
        return ResultColumns(chunks: chunks)
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
            
            if type != .integer {
                diagnostics.add(.init(
                    "JOIN clause should return an 'INTEGER', got '\(type)'",
                    at: expression.location
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
                as: table.alias?.identifier.value,
                isOptional: isOptional,
                onlyColumnsIn: usedColumns
            )
            
            return
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            let resultColumns = inNewEnvironment { inferrer in
                inferrer.typeCheck(select: selectStmt)
            }
            
            // Insert the result of the subquery into the environment
            if let alias {
                env.insert(alias.identifier.value, ty: resultColumns.type)
            }
            
            // Also insert each column into the env. So you dont
            // have to do `alias.column`
            for (name, type) in resultColumns.allColumns {
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
        as alias: Substring? = nil,
        isOptional: Bool = false,
        onlyColumnsIn columns: Set<Substring> = [],
        globallyAddColumns: Bool = true
    ) {
        // Insert real name not alias. These are used later for observation tracking
        // so an alias is no good since it will always be the actual table name.
        usedTableNames.insert(table.name)
        
        env.insert(
            alias ?? table.name,
            ty: isOptional ? .optional(table.type) : table.type
        )
        
        if globallyAddColumns {
            for column in table.columns where columns.isEmpty || columns.contains(column.key) {
                env.insert(column.key, ty: isOptional ? .optional(column.value) : column.value)
            }
        }
        
        // Make rank available, but only via by direct name so it isnt
        // included in the result columns during a `SELECT *`
        if table.kind == .fts5 {
            env.insert("rank", ty: .real, explicitAccessOnly: true)
        }
    }
    
    private mutating func insertColumnsIntoEnv(columns: borrowing Columns) {
        for column in columns {
            env.insert(column.key, ty: column.value)
        }
    }
    
    mutating func typeCheck(createTable: CreateTableStmtSyntax) {
        if pragmas.contains(.requireStrictTables)
            && !createTable.options.kind.contains(.strict) {
            diagnostics.add(.init(
                "Missing STRICT table option",
                at: createTable.location,
                suggestion: .append(" STRICT")
            ))
        }
        
        switch createTable.kind {
        case let .select(selectStmt):
            let signature = signature(for: selectStmt)
            let columns = signature.output.allColumns
            schema[createTable.name.value] = Table(
                name: createTable.name.value,
                columns: columns,
                primaryKey: primaryKey(of: createTable, columns: columns),
                kind: .normal
            )
        case let .columns(columnsDefs):
            var columns: Columns = [:]
            for (name, def) in columnsDefs {
                columns[name.value] = typeFor(
                    column: def,
                    tableColumns: columns
                )
            }
            
            validateTableConstraints(of: createTable, columns: columns)
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
            diagnostics.add(.init("Cannot alter virtual table", at: alterTable.name.location))
            return
        case .view:
            diagnostics.add(.init("Cannot alter view", at: alterTable.name.location))
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
            table.columns[column.name.value] = typeFor(column: column, tableColumns: table.columns)
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
        
        for trigger in schema.triggers.values {
            if trigger.targetTable == dropTable.tableName.name.value {
                // Dropping a table automatically removes any trigger its the target of.
                schema[trigger: trigger.name] = nil
            } else {
                guard trigger.usedTables.contains(dropTable.tableName.name.value) else { continue }
                
                // SQLite seemingly from my tests will allow this to happen but I swear I've
                // had errors from it before. But error if the table is used in a trigger.
                // Any trigger where its the target table will automatically be deleted
                // so those dont matter
                diagnostics.add(.init(
                    "Table referenced in statements of trigger '\(trigger.name)'",
                    at: dropTable.location
                ))
            }
        }
        
        schema[dropTable.tableName.name.value] = nil
    }
    
    /// Will figure out the final SQL column type from the syntax
    private mutating func typeFor(
        column: borrowing ColumnDefSyntax,
        tableColumns: borrowing Columns
    ) -> Type {
        var isNotNullable = false
        for constraint in column.constraints {
            switch constraint.kind {
            case .primaryKey, .notNull:
                // Technically you can have a NULL primary key but I don't
                // think people actually do that...
                isNotNullable = true
            case .check(let expr):
                inNewEnvironment { typeChecker in
                    typeChecker.insertColumnsIntoEnv(columns: tableColumns)
                    _ = typeChecker.typeCheck(expr)
                }
            case .default(let expr):
                inNewEnvironment { typeChecker in
                    _ = typeChecker.typeCheck(expr)
                }
            case .foreignKey(let fk):
                if schema[fk.foreignTable.value] == nil {
                    diagnostics.add(.tableDoesNotExist(fk.foreignTable))
                }
            case .generated(let expr, _):
                inNewEnvironment { typeChecker in
                    typeChecker.insertColumnsIntoEnv(columns: tableColumns)
                    _ = typeChecker.typeCheck(expr)
                }
            case .unique, .collate:
                break
            }
        }
        
        // Validate it is an actual SQLite type since SQlite doesnt care.
        if !Type.validTypeNames.contains(column.type.name.value) {
            diagnostics.add(.init(
                "Invalid type '\(column.type.name.value)'",
                at: column.type.location
            ))
        }
        
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
                    at: constraint.1.location
                ))
            }
            
            return []
        }
        
        // Make sure only 1 primary key constraint is added.
        // This allows for PRIMARY KEY(foo, bar) but not for multiple of those constraints
        if !byColumnConstraints.isEmpty, let constraint = byTableConstraints.first {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.1.location))
        } else if byColumnConstraints.count > 1, let constraint = byColumnConstraints.last {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.location))
        } else if byTableConstraints.count > 1, let constraint = byTableConstraints.last {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.1.location))
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
    
    private mutating func validateTableConstraints(
        of stmt: CreateTableStmtSyntax,
        columns: Columns
    ) {
        for constraint in stmt.constraints {
            switch constraint.kind {
            case .check(let expr):
                inNewEnvironment { typeChecker in
                    typeChecker.insertColumnsIntoEnv(columns: columns)
                    _ = typeChecker.typeCheck(expr)
                }
            case .foreignKey(let fkColumns, let fkClause):
                // Make sure listed columns exist
                for column in fkColumns {
                    guard columns[column.value] == nil else { continue }
                    diagnostics.add(.columnDoesNotExist(column))
                }
                
                // Make sure referenced table exists
                guard let foreignTable = schema[fkClause.foreignTable.value] else {
                    diagnostics.add(.tableDoesNotExist(fkClause.foreignTable))
                    return
                }
                
                // Make sure referenced columns exist
                for column in fkClause.foreignColumns {
                    guard foreignTable.columns[column.value] == nil else { continue }
                    diagnostics.add(.columnDoesNotExist(column))
                }
            case .primaryKey, .unique:
                break
            }
        }
    }
    
    mutating func typeCheck(fts5Table: borrowing CreateVirtualTableStmtSyntax) {
        var columns: Columns = [:]
        
        for argument in fts5Table.arguments {
            switch argument {
            case let .fts5Column(name, typeName, notNull, _):
                guard let typeName = typeName?.name.value else {
                    diagnostics.add(.init("Missing column type", at: name.location))
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
