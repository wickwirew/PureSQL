//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import OrderedCollections

public struct CompiledTable {
    public var name: Substring
    public var columns: OrderedDictionary<Substring, Ty>
    
    var type: Ty {
        return .row(.named(columns))
    }
}

public enum CompiledStmt {
    case query(Signature)
    case table(CompiledTable)
}

public struct Signature: CustomReflectable {
    public var parameters: [Int: Parameter]
    public var output: Ty
    
    public var customMirror: Mirror {
        let outputTypes: [String] = if case let .row(.named(columns)) = output {
            columns.elements.map { "\($0) \($1)" }
        } else {
            []
        }
        
        return Mirror(
            self,
            children: [
                "parameters": parameters.values
                    .map(\.self)
                    .sorted(by: { $0.index < $1.index }),
                "output": outputTypes
            ]
        )
    }
}

public struct Parameter {
    public let type: Ty
    public let index: Int
    public let name: Substring?
}

struct Compiler {
    private(set) var schema: Schema
    private(set) var diagnostics = Diagnostics()
    private(set) var queries: [Signature] = []
    
    public init(
        schema: Schema = Schema(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    mutating func compile(_ stmts: [Stmt]) {
        for stmt in stmts {
            switch stmt.accept(visitor: &self) {
            case let .table(table):
                schema[table.name] = table
            case let .query(query):
                queries.append(query)
            case nil:
                break
            }
        }
    }
    
    mutating func compile(_ source: String) {
        compile(Parsers.parse(source: source))
    }
}

extension Compiler: StmtVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmt) -> CompiledStmt? {
        switch stmt.kind {
        case let .select(selectStmt):
            var typeInferrer = TypeInferrer(env: Environment(), schema: schema)
            let solution = typeInferrer.check(selectStmt)
            diagnostics.add(contentsOf: solution.diagnostics)
            guard case let .row(.named(columns)) = solution.signature.output else { return nil }
            return .table(CompiledTable(name: stmt.name.value, columns: columns))
        case let .columns(columns):
            return .table(CompiledTable(
                name: stmt.name.value,
                columns: columns.reduce(into: [:]) { $0[$1.value.name.value] = typeFor(column: $1.value) }
            ))
        }
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmt) -> CompiledStmt? {
        guard var table = schema[stmt.name.value] else {
            diagnostics.add(.init("Table '\(stmt.name)' does not exist", at: stmt.name.range))
            return nil
        }
        
        switch stmt.kind {
        case let .rename(newName):
            schema[stmt.name.value] = nil
            schema[newName.value] = table
        case let .renameColumn(oldName, newName):
            table.columns = table.columns.reduce(into: [:]) { $0[$1.key == oldName.value ? newName.value : $1.key] = $1.value }
        case let .addColumn(column):
            table.columns[column.name.value] = typeFor(column: column)
        case let .dropColumn(column):
            table.columns[column.value] = nil
        }
        
        return .table(table)
    }
    
    mutating func visit(_ stmt: borrowing SelectStmt) -> CompiledStmt? {
        var queryCompiler = QueryCompiler(schema: schema)
        let (query, diags) = queryCompiler.compile(select: stmt)
        diagnostics.add(contentsOf: diags)
        return .query(query)
    }
    
    mutating func visit(_ stmt: borrowing InsertStmt) -> CompiledStmt? {
        var queryCompiler = QueryCompiler(schema: schema)
        let (query, diags) = queryCompiler.compile(insert: stmt)
        diagnostics.add(contentsOf: diags)
        return .query(query)
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmt) -> CompiledStmt? {
        return nil
    }
    
    private func typeFor(column: borrowing ColumnDef) -> Ty {
        // Technically you can have a NULL primary key but I don't
        // think people actually do that...
        let isNotNullable = column.constraints
            .contains { $0.isPkConstraint || $0.isNotNullConstraint }
        
        if isNotNullable {
            return .nominal(column.type.name.value)
        } else {
            return .optional(.nominal(column.type.name.value))
        }
    }
}

struct QueryCompiler {
    private(set) var environment = Environment()
    private(set) var diagnositics = Diagnostics()
    private(set) var schema: Schema
    
    private(set) var inputs: [Int: Parameter] = [:]
    
    init(schema: Schema) {
        self.schema = schema
    }
    
    mutating func compile(select: SelectStmt) -> (Signature, Diagnostics) {
        if let cte = select.cte?.value {
            compile(cte: cte)
        }
        
        switch select.selects.value {
        case let .single(select):
            let result = compile(select)
            return (result, diagnositics)
        case .compound:
            fatalError()
        }
    }
    
    mutating func compile(insert: InsertStmt) -> (Signature, Diagnostics) {
        if let cte = insert.cte {
            compile(cte: cte)
        }
        
        guard let table = schema[insert.tableName.name.value] else {
            diagnositics.add(.tableDoesNotExist(insert.tableName.name))
            return (Signature(parameters: [:], output: .error), diagnositics)
        }
        
        let inputType: Ty
        if let columns = insert.columns {
            var columnTypes: [Ty] = []
            for column in columns {
                guard let def = table.columns[column.value] else {
                    diagnositics.add(.columnDoesNotExist(column))
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
            let (query, _) = compile(select: values.select)
            _ = inputType.unify(with: query.output, at: insert.range, diagnostics: &diagnositics)
        } else {
            // TODO: Using 'DEFALUT VALUES' make sure all columns
            // TODO: actually have default values or null
        }
        
        let ty: Ty = if let returningClause = insert.returningClause {
            compile(returningClause: returningClause, sourceTable: table)
        } else {
            .row(.empty)
        }
        
        return (Signature(parameters: inputs, output: ty), diagnositics)
    }
    
    private mutating func compile(
        returningClause: ReturningClause,
        sourceTable: CompiledTable
    ) -> Ty {
        var resultColumns: Columns = [:]
        
        for value in returningClause.values {
            switch value {
            case let .expr(expr, alias):
                let solution = check(expression: expr)
                
                guard let name = alias?.value ?? solution.lastName else {
                    diagnositics.add(.nameRequired(at: expr.range))
                    continue
                }
                
                resultColumns[name] = solution.signature.output
            case .all:
                // TODO: See TODO on `Columns` typealias
                resultColumns.merge(resultColumns, uniquingKeysWith: { $1 })
            }
        }
        
        return .row(.named(resultColumns))
    }

    @discardableResult
    private mutating func check(expression: Expression) -> Solution {
        var typeInferrer = TypeInferrer(env: environment, schema: schema)
        let solution = typeInferrer.check(expression)
        diagnositics.add(contentsOf: solution.diagnostics)
        inputs.merge(solution.signature.parameters, uniquingKeysWith: {$1})
        return solution
    }
    
    private mutating func compile(cte: CommonTableExpression) {
        let (query, _) = compile(select: cte.select)

        let tableTy: Ty
        if cte.columns.isEmpty {
            tableTy = query.output
        } else {
            guard case let .row(row) = query.output else {
                return assertionFailure("Select is not a row?")
            }
            
            let columnTypes = row.types
            if columnTypes.count != cte.columns.count {
                diagnositics.add(.init(
                    "CTE expected \(cte.columns.count) columns, but got \(row.count)",
                    at: cte.range
                ))
            }
            
            tableTy = .row(.named(
                (0..<min(columnTypes.count, cte.columns.count))
                    .reduce(into: [:]) { $0[cte.columns[$1].value] = columnTypes[$1] }
            ))
        }
        
        environment.insert(cte.table.value, ty: tableTy)
    }
    
    private mutating func compile(_ select: SelectCore) -> Signature {
        switch select {
        case let .select(select):
            return compile(select: select)
        case .values:
            fatalError()
        }
    }
    
    private mutating func compile(select: SelectCore.Select) -> Signature {
        if let from = select.from {
            compile(from: from)
        }
        
        let output = compile(resultColumns: select.columns)
        
        if let whereExpr = select.where {
            compile(where: whereExpr)
        }
        
        if let groupBy = select.groupBy {
            for expression in groupBy.expressions {
                _ = check(expression: expression)
            }
            
            if let having = groupBy.having {
                let solution = check(expression: having)
                
                if solution.type != .bool, solution.type != .integer {
                    diagnositics.add(.init(
                        "HAVING clause should return a 'BOOL' or 'INTEGER', got '\(solution.type)'",
                        at: having.range
                    ))
                }
            }
        }
        
        return Signature(parameters: inputs, output: output)
    }
    
    private mutating func compile(from: From) {
        switch from {
        case let .tableOrSubqueries(t):
            for table in t {
                compile(table)
            }
        case let .join(joinClause):
            compile(joinClause: joinClause)
        }
    }
    
    private mutating func compile(where expr: Expression) {
        let solution = check(expression: expr)
        
        if solution.type != .bool, solution.type != .integer {
            diagnositics.add(.init(
                "WHERE clause should return a 'BOOL' or 'INTEGER', got '\(solution.type)'",
                at: expr.range
            ))
        }
    }
    
    private mutating func compile(resultColumns: [ResultColumn]) -> Ty {
        var columns: OrderedDictionary<Substring, Ty> = [:]
        
        for resultColumn in resultColumns {
            switch resultColumn {
            case let .expr(expr, alias):
                let solution = check(expression: expr)
                
                let name = alias?.value ?? solution.lastName
                columns[name ?? "__name_required__"] = solution.signature.output
                
                if name == nil {
                    diagnositics.add(.nameRequired(at: expr.range))
                }
            case let .all(tableName):
                if let tableName {
                    if let table = environment[tableName.value]?.type {
                        guard case let .row(.named(tableColumns)) = table else {
                            diagnositics.add(.init("'\(tableName)' is not a table", at: tableName.range))
                            continue
                        }
                        
                        for (name, type) in tableColumns {
                            columns[name] = type
                        }
                    } else {
                        diagnositics.add(.init("Table '\(tableName)' does not exist", at: tableName.range))
                    }
                } else {
                    for (name, type) in environment {
                        switch type.type {
                        case .row: continue // Ignore tables
                        default: columns[name] = type.type
                        }
                    }
                }
            }
        }
        
        return .row(.named(columns))
    }
    
    private mutating func compile(joinClause: JoinClause) {
        compile(joinClause.tableOrSubquery)
        
        for join in joinClause.joins {
            compile(join: join)
        }
    }
    
    private mutating func compile(join: JoinClause.Join) {
        switch join.constraint {
        case let .on(expression):
            compile(join.tableOrSubquery, joinOp: join.op)
            
            let solution = check(expression: expression)
            
            if solution.type != .bool, solution.type != .integer {
                diagnositics.add(.init(
                    "JOIN clause should return a 'BOOL' or 'INTEGER', got '\(solution.type)'",
                    at: expression.range
                ))
            }
        case let .using(columns):
            compile(join.tableOrSubquery, joinOp: join.op, columns: columns.reduce(into: []) { $0.insert($1.value) })
        case .none:
            compile(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func compile(
        _ tableOrSubquery: TableOrSubquery,
        joinOp: JoinOperator? = nil,
        columns usedColumns: Set<Substring> = []
    ) {
        switch tableOrSubquery {
        case let .table(table):
            let tableName = TableName(schema: table.schema, name: table.name)
            
            guard let envTable = schema[tableName.name.value] else {
                // TODO: Add diag
                environment.insert(table.name.value, ty: .error)
                return
            }
            
            let isOptional = switch joinOp {
            case nil, .inner: false
            default: true
            }

            environment.insert(
                table.alias?.value ?? table.name.value,
                ty: isOptional ? .optional(envTable.type) : envTable.type
            )
            
            for column in envTable.columns where usedColumns.isEmpty || usedColumns.contains(column.key) {
                environment.insert(column.key, ty: isOptional ? .optional(column.value) : column.value)
            }
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            var compiler = QueryCompiler(schema: schema)
            let (result, diags) = compiler.compile(select: selectStmt)
            
            diagnositics.add(contentsOf: diags)
            
            inputs.merge(result.parameters, uniquingKeysWith: {$1})
            
            if let alias {
                environment.insert(alias.value, ty: result.output)
            }
            
            guard case let .row(.named(columns)) = result.output else {
                fatalError("SELECT did not result a row type")
            }
            
            for (name, type) in columns {
                environment.insert(name, ty: type)
            }
        case let .join(joinClause):
            compile(joinClause: joinClause)
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
