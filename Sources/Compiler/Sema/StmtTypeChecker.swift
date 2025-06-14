//
//  StmtTypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections

/// Type checks a single statement. At this current time it is only valid for one statement.
/// It internally tracks metadata about the statement which stays even till after the
/// type checking is done. Allows the caller to get said info if need be.
struct StmtTypeChecker {
    typealias Signature = (parameters: [Parameter<Substring?>], output: ResultColumns)
    
    /// The environment in which the query executes. Any joined in tables
    /// will be added to this.
    private(set) var env: Environment
    /// The entire database schema
    private(set) var schema: Schema
    /// Any CTE that was declared with the statement.
    /// Keeping these separate from the schema so they don't get passed to the next statement
    private(set) var ctes: [Substring: Table] = [:]
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
    
    /// Initializes a `QualifiedName` and emits any diagnostics on a failure.
    /// If the schema does not exists `nil` will be returned.
    private mutating func qualifedName(for name: TableNameSyntax) -> QualifiedName {
        return qualifedName(for: name.name, in: name.schema)
    }
    
    /// Initializes a `QualifiedName` and emits any diagnostics on a failure.
    /// If the schema does not exists `nil` will be returned.
    private mutating func qualifedName(
        for name: IdentifierSyntax,
        in schema: IdentifierSyntax?,
        isTemp: Bool = false
    ) -> QualifiedName {
        guard let schema else {
            return QualifiedName(name: name.value, schema: isTemp ? .temp : .main)
        }
        
        if isTemp {
            diagnostics.add(.init("Temporary table name must be unqualified", at: schema.location))
        }
        
        guard let schemaName = SchemaName(schema.value) else {
            diagnostics.add(.init("Schema '\(schema)' does not exist", at: schema.location))
            return QualifiedName(name: name.value, schema: nil)
        }

        return QualifiedName(name: name.value, schema: schemaName)
    }
    
    private mutating func value<Value>(
        from result: Environment.LookupResult<Value>,
        for identifier: IdentifierSyntax
    ) -> Value? {
        switch result {
        case .success(let value):
            return value
        case .ambiguous(let value):
            diagnostics.add(.ambiguous(identifier.value, at: identifier.location))
            return value
        case .columnDoesNotExist:
            diagnostics.add(.columnDoesNotExist(identifier))
            return nil
        case .tableDoesNotExist:
            diagnostics.add(.tableDoesNotExist(identifier))
            return nil
        case .schemaDoesNotExist:
            diagnostics.add(.schemaDoesNotExist(identifier))
            return nil
        }
    }
}

extension StmtTypeChecker: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> ResultColumns {
        typeCheck(createTable: stmt)
        return .empty
    }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> ResultColumns {
        typeCheck(alterTable: stmt)
        return .empty
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) -> ResultColumns {
        return typeCheck(select: stmt)
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) -> ResultColumns {
        return typeCheck(insert: stmt)
    }
    
    mutating func visit(_ stmt: UpdateStmtSyntax) -> ResultColumns {
        return typeCheck(update: stmt)
    }
    
    mutating func visit(_ stmt: DeleteStmtSyntax) -> ResultColumns {
        return typeCheck(delete: stmt)
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> ResultColumns {
        return stmt.statement.accept(visitor: &self)
    }
    
    mutating func visit(_ stmt: PragmaStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: DropTableStmtSyntax) -> ResultColumns {
        typeCheck(dropTable: stmt)
        return .empty
    }
    
    mutating func visit(_ stmt: CreateIndexStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.name, in: stmt.schemaName)
        let tableName = qualifedName(for: stmt.table, in: stmt.schemaName)

        guard let table = schema[tableName] else {
            diagnostics.add(.tableDoesNotExist(stmt.table))
            return .empty
        }
        
        importTable(table)
        
        if !stmt.ifNotExists, schema[index: name] != nil {
            diagnostics.add(.init("Index with name already exists", at: stmt.name.location))
        }
        
        if let whereExpr = stmt.whereExpr {
            _ = typeCheck(whereExpr)
        }
        
        schema[index: name] = Index(name: name, table: table.name)
        
        return .empty
    }
    
    mutating func visit(_ stmt: DropIndexStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.name, in: stmt.schemaName)
        
        if !stmt.ifExists, schema[index: name] == nil {
            diagnostics.add(.init("Index does not exist", at: stmt.name.location))
        }
        
        schema[index: name] = nil
        return .empty
    }
    
    mutating func visit(_ stmt: ReindexStmtSyntax) -> ResultColumns {
        guard let nameIdentifier = stmt.name else { return .empty }
        let name = qualifedName(for: nameIdentifier, in: stmt.schemaName)
        
        guard schema[name] != nil || schema[index: name] != nil else {
            diagnostics.add(.init("No table or index with name", at: nameIdentifier.location))
            return .empty
        }
        
        return .empty
    }
    
    mutating func visit(_ stmt: CreateViewStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.name, in: stmt.schemaName, isTemp: stmt.temp)
        
        guard schema[name] == nil else {
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
                columns.append(types[index], for: stmt.columnNames[index].value)
            }
        }
        
        schema[name] = Table(
            name: name,
            columns: columns,
            primaryKey: [/* In the future we can analyze the select to see if we can do better */],
            kind: .view
        )
        
        return .empty
    }
    
    mutating func visit(_ stmt: DropViewStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.viewName, in: stmt.schemaName)
        
        guard let table = schema[name] else {
            if !stmt.ifExists {
                diagnostics.add(.init("View with name does not exist", at: stmt.viewName.location))
            }
            return .empty
        }
        
        if table.kind != .view {
            diagnostics.add(.init("Table is not a view", at: stmt.viewName.location))
        }
        
        schema[name] = nil
        
        return .empty
    }
    
    mutating func visit(_ stmt: CreateVirtualTableStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.tableName.name, in: stmt.tableName.schema)
        
        if !stmt.ifNotExists, schema[name] != nil {
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
    
    mutating func visit(_ stmt: CreateTriggerStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.triggerName, in: stmt.schemaName)
        let tableName = qualifedName(for: stmt.tableName, in: stmt.tableSchemaName)
        
        guard let table = schema[tableName] else {
            diagnostics.add(.tableDoesNotExist(stmt.tableName))
            return .empty
        }
        
        if !stmt.ifNotExists, schema[trigger: name] != nil {
            diagnostics.add(.init(
                "Trigger with name already exists",
                at: stmt.triggerName.location
            ))
        }
        
        switch stmt.action {
        case .delete:
            importTable(table, as: "old", qualifiedAccessOnly: true)
        case .insert:
            importTable(table, as: "new", qualifiedAccessOnly: true)
        case let .update(columns):
            importTable(table, as: "new", qualifiedAccessOnly: true)
            importTable(table, as: "old", qualifiedAccessOnly: true)
            
            // Make sure all columns in the update statement actually exist
            if let columns {
                for column in columns {
                    if !table.columns.contains(key: column.value) {
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
        
        schema[trigger: name] = Trigger(
            name: name,
            targetTable: tableName,
            usedTables: usedTableNames.subtracting([table.name.name])
        )
        
        return .empty
    }
    
    mutating func visit(_ stmt: DropTriggerStmtSyntax) -> ResultColumns {
        let name = qualifedName(for: stmt.triggerName, in: stmt.schemaName)
        if !stmt.ifExists, schema[trigger: name] == nil {
            diagnostics.add(.init("Trigger with name does not exist", at: stmt.triggerName.location))
        }
        
        schema[trigger: name] = nil
        return .empty
    }
    
    mutating func visit(_ stmt: BeginStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: CommitStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: SavepointStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: ReleaseStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: RollbackStmtSyntax) -> ResultColumns {
        return .empty
    }
    
    mutating func visit(_ stmt: VacuumStmtSyntax) -> ResultColumns {
        return .empty
    }
}

extension StmtTypeChecker {
    mutating func typeCheck(
        select: SelectStmtSyntax,
        potentialNames: [IdentifierSyntax]? = nil
    ) -> ResultColumns {
        typeCheck(with: select.with)
        
        // Type check limit before since it does not have access
        // to any selected columns
        if let limit = select.limit {
            _ = typeCheck(limit.expr)
        }
        
        let resultColumns = typeCheck(
            selects: select.selects.value,
            at: select.location,
            potentialNames: potentialNames
        )
        
        // FIX-ME: This is a little odd. Aliased columns are inserted automatically
        // when the result columns are declared. Compound select statements (UNION)
        // are executed in a new environment so those columns are lost. So we have
        // to re-insert any missing columns into the env before type checking the
        // order by clause to make sure it has access. This could really be cleaned
        // up. Not sure if the environment should track selected columns, then
        // the `inNewEnvironment` could make sure to automatically retain those?
        // However for compound statements that would still error since the second
        // would try to double insert the column in the second select.... Needless
        // to say this stays for now but I dont like it.
        inNewEnvironment(extendCurrentEnv: true) { typeChecker in
            for column in resultColumns.allColumns where !typeChecker.env.hasColumn(named: column.key) {
                typeChecker.env.import(column: column.key, with: column.value)
            }
            
            for term in select.orderBy {
                _ = typeChecker.typeCheck(term.expr)
            }
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
                inferenceState.unify(
                    type,
                    with: inferenceState.solution(for: secondColumns[index]),
                    at: location
                )
                index += 1
                return type
            }
        }
    }
    
    mutating func typeCheck(insert: InsertStmtSyntax) -> ResultColumns {
        typeCheck(with: insert.with)
        
        let tableName = qualifedName(for: insert.tableName)
        
        guard let table = schema[tableName] else {
            diagnostics.add(.tableDoesNotExist(insert.tableName.name))
            return .empty
        }
        
        usedTableNames.insert(table.name.name)
        
        let inputType: Type
        if let columns = insert.columns {
            var columnTypes: [Type] = []
            for column in columns {
                guard let def = table.columns[column.value].first else {
                    diagnostics.add(.columnDoesNotExist(column))
                    columnTypes.append(.error)
                    continue
                }
                
                columnTypes.append(def)
            }
            inputType = .row(.fixed(columnTypes))
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
        typeCheck(with: update.with)
        
        let tableName = qualifedName(for: update.tableName.tableName)
        
        guard let table = schema[tableName] else {
            diagnostics.add(.tableDoesNotExist(update.tableName.tableName.name))
            return .empty
        }
        
        importTable(table)
        
        for set in update.sets {
            let (valueType, valueName) = typeCheck(set.expr)
            
            switch set.column {
            // SET column = value
            case let .single(column):
                nameInferrer.suggest(name: column.value, for: valueName)
                
                guard let column = table.columns[column.value].first else {
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
        typeCheck(with: delete.with)
        
        let tableName = qualifedName(for: delete.table.tableName)
        
        guard let table = schema[tableName] else {
            diagnostics.add(.tableDoesNotExist(delete.table.tableName.name))
            return .empty
        }
        
        importTable(table)
        
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
        var columns: [Type] = []
        
        for name in names {
            if let column = table.columns[name.value].first {
                columns.append(column)
            } else {
                diagnostics.add(.columnDoesNotExist(name))
                columns.append(.error)
            }
        }
        
        return .row(.fixed(columns))
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
                
                resultColumns.append(type, for: name)
            case .all:
                resultColumns.append(contentsOf: sourceTable.columns)
            }
        }
        
        return ResultColumns(columns: resultColumns, table: nil)
    }
    
    private mutating func typeCheck(with: WithSyntax?) {
        guard let with else { return }
        
        for cte in with.ctes {
            let table = inNewEnvironment { typeChecker in
                typeChecker.typeCheck(cte: cte, recursive: with.recursive)
            }
            
            ctes[cte.table.value] = table
        }
    }
    
    private mutating func typeCheck(
        cte: CommonTableExpressionSyntax,
        recursive: Bool
    ) -> Table {
        let cteName = QualifiedName(name: cte.table.value, schema: nil)
        
        if cte.columns.isEmpty {
            let resultColumns = typeCheck(select: cte.select)
            return Table(name: cteName, columns: resultColumns.allColumns, kind: .cte)
        } else {
            // CTE's can reference themselves so we need to create a table to
            // represent this CTE with all columns as type variables.
            let thisCte = Table(
                name: cteName,
                columns: cte.columns.reduce(into: [:]) { columns, name in
                    columns.append(inferenceState.freshTyVar(for: name), for: name.value)
                },
                kind: .cte
            )
            
            ctes[thisCte.name.name] = thisCte
            
            let resultColumns = typeCheck(select: cte.select)
            let columnTypes = resultColumns.allColumns.values
            if columnTypes.count != cte.columns.count {
                diagnostics.add(.init(
                    "CTE expected \(cte.columns.count) columns, but got \(columnTypes.count)",
                    at: cte.location
                ))
            }
            
            // Simply return the table but getting the solution types so the substitution
            // map retains it's integrity.
            return thisCte.mapTypes { inferenceState.solution(for: $0) }
        }
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
                
                types.append(.row(.fixed(columns)))
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
                inferenceState.unify(type, with: .integer, at: having.location)
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
    
    /// Type checks a `WHERE` expression
    private mutating func typeCheck(where expr: any ExprSyntax) {
        let (type, _) = typeCheck(expr)
        // Needs to return an `INTEGER` e.g. boolean
        inferenceState.unify(type, with: .integer, at: expr.location)
    }
    
    /// Type checks and calculates the returned columns from a `SELECT` stmt.
    ///
    /// Note: This is going to do a little extra than just infer the column names
    /// and types. It will try to chunk them out by table. So if the user does
    /// a query like `SELECT foo.*, bar.*` we can embed the fact that they
    /// selected all columns from foo and bar so the table structs can be embded
    /// within the output type.
    private mutating func typeCheck(resultColumns: [ResultColumnSyntax]) -> ResultColumns {
        var columns: Columns = [:]
        var table: Substring?
        // Each chunk is either a list of specifically listed columns
        // or a select all of a table.
        var chunks: [ResultColumns.Chunk] = []
        
        // Breaks off the current columns into a chunk then starts a new one.
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
                
                columns.append(type, for: name)
                nameInferrer.suggest(name: name, for: names)
                
                // We selected a single column, so clear out the table
                // since its not a select all of a table.
                table = nil
                
                if let alias {
                    env.import(column: alias.identifier.value, with: type)
                }
            case let .all(tableName):
                if let tableName {
                    let table = value(
                        from: env.resolve(
                            table: tableName.value,
                            schema: nil
                        ),
                        for: tableName
                    ) ?? .error
                    
                    // Insert any columns that have been defined before the `table.*`
                    breakOffCurrentChunkIfNeeded()
                    
                    // Add table columns as a chunk
                    chunks.append(ResultColumns.Chunk(
                        columns: table.columns,
                        table: tableName.value
                    ))
                } else {
                    // No table specified so import everything in from the environment.
                    breakOffCurrentChunkIfNeeded()
                    
                    for table in env.allImportedTables {
                        chunks.append(ResultColumns.Chunk(
                            columns: table.columns,
                            table: table.name.name
                        ))
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
            inferenceState.unify(type, with: .integer, at: expression.location)
        case .using:
            // TODO: Actually check columns
            typeCheck(join.tableOrSubquery, joinOp: join.op)
        case .none:
            typeCheck(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func typeCheck(
        _ tableOrSubquery: TableOrSubquerySyntax,
        joinOp: JoinOperatorSyntax? = nil
    ) {
        switch tableOrSubquery.kind {
        case let .table(table):
            let isOptional = switch joinOp?.kind {
            case nil, .inner: false
            default: true
            }
            
            let tableName = qualifedName(for: table.name, in: table.schema)
            
            // TODO: Delete `ctes`s
            guard let envTable = schema[tableName] ?? ctes[table.name.value] else {
                env.import(table: .error, isOptional: isOptional)
                diagnostics.add(.tableDoesNotExist(table.name))
                return
            }
            
            importTable(envTable, as: table.alias?.identifier.value, isOptional: isOptional)
        case .tableFunction:
            fatalError("Not yet implemented")
        case let .subquery(selectStmt, alias):
            let resultColumns = inNewEnvironment { inferrer in
                inferrer.typeCheck(select: selectStmt)
            }
            
            // Insert the result of the subquery into the environment
            if let alias {
                let table = Table(
                    name: QualifiedName(name: alias.identifier.value, schema: nil),
                    columns: resultColumns.allColumns,
                    primaryKey: [],
                    kind: .subquery
                )
                importTable(table, isOptional: false)
            } else {
                // No alias so it cannot be imported as a table so we can
                // just import the columns only.
                env.import(columns: resultColumns.allColumns)
            }
        case let .join(joinClause):
            let joinEnv = inNewEnvironment { typeChecker in
                typeChecker.typeCheck(joinClause: joinClause)
                return typeChecker.env
            }
            
            env.importNonLocals(in: joinEnv)
        case let .tableOrSubqueries(tableOrSubqueries):
            var envDiffs: [Environment.Diff] = []
            let startingEnv = env
            
            for tableOrSubquery in tableOrSubqueries {
                let newEnv = inNewEnvironment { typeChecker in
                    typeChecker.typeCheck(tableOrSubquery)
                    return typeChecker.env
                }
                
                envDiffs.append(startingEnv.nonLocalsAdded(in: newEnv))
            }
            
            for envDiff in envDiffs {
                env.add(diff: envDiff)
            }
        }
    }

    private func assumeRow(_ ty: Type) -> Type.Row {
        guard case let .row(rowTy) = ty else {
            assertionFailure("This cannot happen")
            return .fixed([])
        }

        return rowTy
    }
    
    /// Will insert the table and all of its columns into the environment.
    /// Allows queries to access the columns at a top level.
    ///
    /// If `isOptional` is true, all of the column types will be made optional
    /// as well. Useful in joins that may or may not have a match, e.g. Outer
    private mutating func importTable(
        _ table: Table,
        as alias: Substring? = nil,
        isOptional: Bool = false,
        qualifiedAccessOnly: Bool = false
    ) {
        // Insert real name not alias. These are used later for observation tracking
        // so an alias is no good since it will always be the actual table name.
        usedTableNames.insert(table.name.name)
        
        // Table is always accessible by it's name even if aliased
        env.import(
            table: table,
            alias: alias,
            isOptional: isOptional,
            qualifiedAccessOnly: qualifiedAccessOnly
        )
    }
    
    mutating func typeCheck(createTable: CreateTableStmtSyntax) {
        let tableName = qualifedName(
            for: createTable.name,
            in: createTable.schemaName,
            isTemp: createTable.isTemporary
        )
        
        switch createTable.kind {
        case let .select(selectStmt):
            let signature = signature(for: selectStmt)
            let columns = signature.output.allColumns
            schema[tableName] = Table(
                name: tableName,
                columns: columns,
                primaryKey: primaryKey(of: createTable, columns: columns),
                kind: .normal
            )
        case let .columns(columnsDefs, constraints, options):
            var columns: Columns = [:]
            for (name, def) in columnsDefs {
                let type = typeFor(
                    column: def,
                    tableColumns: columns,
                    tableName: createTable.name.value
                )
                columns.append(type, for: name.value)
            }
            
            validateTableConstraints(
                of: createTable,
                columns: columns,
                constraints: constraints
            )
            
            schema[tableName] = Table(
                name: tableName,
                columns: columns,
                primaryKey: primaryKey(of: createTable, columns: columns),
                kind: .normal
            )
            
            if pragmas.contains(.requireStrictTables)
                && !options.kind.contains(.strict) {
                diagnostics.add(.init(
                    "Missing STRICT table option",
                    at: createTable.location,
                    suggestion: .append(" STRICT")
                ))
            }
        }
    }
    
    mutating func typeCheck(alterTable: AlterTableStmtSyntax) {
        var tableName = qualifedName(for: alterTable.name, in: alterTable.schemaName)
        
        guard var table = schema[tableName] else {
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
        case let .rename(newTableName):
            // Clear out table under original name
            schema[tableName] = nil
            
            // Update name, `table` will be inserted at end of function
            tableName = QualifiedName(name: newTableName.value, schema: tableName.schema)
            table.name = tableName
        case let .renameColumn(oldName, newName):
            table.columns.rename(oldName.value, to: newName.value)
        case let .addColumn(column):
            let newType = typeFor(
                column: column,
                tableColumns: table.columns,
                tableName: table.name.name
            )
            table.columns.append(newType, for: column.name.value)
        case let .dropColumn(column):
            table.columns = Columns(table.columns.filter { $0.key != column.value })
        }
        
        schema[tableName] = table
    }
    
    mutating func typeCheck(dropTable: DropTableStmtSyntax) {
        let tableName = qualifedName(for: dropTable.tableName)
        let tableExists = schema[tableName] != nil
        
        if !tableExists && !dropTable.ifExists {
            diagnostics.add(.tableDoesNotExist(dropTable.tableName.name))
        }
        
        for trigger in schema.triggers.values {
            if trigger.targetTable == tableName {
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
        
        schema[tableName] = nil
    }
    
    /// Will figure out the final SQL column type from the syntax
    private mutating func typeFor(
        column: borrowing ColumnDefSyntax,
        tableColumns: borrowing Columns,
        tableName: Substring
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
                    typeChecker.env.import(columns: tableColumns)
                    _ = typeChecker.typeCheck(expr)
                }
            case .default(let expr):
                inNewEnvironment { typeChecker in
                    _ = typeChecker.typeCheck(expr)
                }
            case .foreignKey(let fk):
                if fk.foreignTable.value == tableName {
                    for foreignColumn in fk.foreignColumns {
                        // Column constraints can reference the column they are
                        // declared for so if its this table and this column then ignore it.
                        guard column.name.value != foreignColumn.value else { continue }
                        
                        if !tableColumns.contains(key: foreignColumn.value) {
                            diagnostics.add(.columnDoesNotExist(foreignColumn))
                        }
                    }
                } else if let table = schema[QualifiedName(name: fk.foreignTable.value, schema: .main)] {
                    for foreignColumn in fk.foreignColumns {
                        if !table.columns.contains(key: foreignColumn.value) {
                            diagnostics.add(.columnDoesNotExist(foreignColumn))
                        }
                    }
                } else {
                    diagnostics.add(.tableDoesNotExist(fk.foreignTable))
                }
            case .generated(let expr, _):
                inNewEnvironment { typeChecker in
                    typeChecker.env.import(columns: tableColumns)
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
    
    private mutating func typeCheck(
        fk: ForeignKeyClauseSyntax,
        column: ColumnDefSyntax,
        tableColumns: Columns
    ) {
        for foreignColumn in fk.foreignColumns {
            // Column constraints can reference themselves
            guard column.name.value != foreignColumn.value else { continue }
            
            if !tableColumns.contains(key: foreignColumn.value) {
                diagnostics.add(.columnDoesNotExist(foreignColumn))
            }
        }
    }
    
    /// Gets the column names of the primary key and validates them
    private mutating func primaryKey(
        of stmt: CreateTableStmtSyntax,
        columns: Columns
    ) -> [Substring] {
        // Any PK define by table constraints
        let byTableConstraints: [([IndexedColumnSyntax], TableConstraintSyntax)] = stmt.constraints?
            .compactMap { constraint -> ([IndexedColumnSyntax], TableConstraintSyntax)? in
                guard case let .primaryKey(columns, _) = constraint.kind else { return nil }
                return (columns, constraint)
            } ?? []
        
        // Any PK defined at the column level
        let byColumnConstraints: [IdentifierSyntax]
        if case let .columns(columns, _, _) = stmt.kind {
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
                    
                    if !columns.contains(key: name.value) {
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
        columns: Columns,
        constraints: [TableConstraintSyntax]
    ) {
        for constraint in constraints {
            switch constraint.kind {
            case .check(let expr):
                inNewEnvironment { typeChecker in
                    typeChecker.env.import(columns: columns)
                    _ = typeChecker.typeCheck(expr)
                }
            case .foreignKey(let fkColumns, let fkClause):
                // Make sure listed columns exist
                for column in fkColumns {
                    guard !columns.contains(key: column.value) else { continue }
                    diagnostics.add(.columnDoesNotExist(column))
                }
                
                let foreignTable = QualifiedName(name: fkClause.foreignTable.value, schema: .main)
                
                // Make sure referenced table exists
                guard let foreignTable = schema[foreignTable] else {
                    diagnostics.add(.tableDoesNotExist(fkClause.foreignTable))
                    return
                }
                
                // Make sure referenced columns exist
                for column in fkClause.foreignColumns {
                    guard !foreignTable.columns.contains(key: column.value) else { continue }
                    diagnostics.add(.columnDoesNotExist(column))
                }
            case .primaryKey, .unique:
                break
            }
        }
    }
    
    mutating func typeCheck(fts5Table: borrowing CreateVirtualTableStmtSyntax) {
        let name = qualifedName(for: fts5Table.tableName)
        var columns: Columns = [:]
        
        for argument in fts5Table.arguments {
            switch argument {
            case let .fts5Column(name, typeName, notNull, _):
                guard let typeName = typeName?.name.value else {
                    diagnostics.add(.init("Missing column type", at: name.location))
                    continue
                }
                
                let type: Type = notNull != nil
                    ? .nominal(typeName)
                    : .optional(.nominal(typeName))
                
                columns.append(type, for: name.value)
            case .fts5Option:
                break // Nothing to do, maybe validate these in the future
            case .unknown:
                fatalError("Not FTS5, caller did not call the right method")
            }
        }
        
        schema[name] = Table(
            name: name,
            columns: columns,
            primaryKey: [],
            kind: .fts5
        )
    }
}

enum TableOrSubqueryResult {
    case table(Table)
    case columns(Columns)
}
