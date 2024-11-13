//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import OrderedCollections

public struct QueryInput: Equatable, CustomStringConvertible, Sendable {
    public var name: Substring
    public var type: Ty
    
    public var description: String {
        return "\(name): \(type)"
    }
}

public struct CompiledQuery {
    public var inputs: [QueryInput]
    public var output: Ty
}

public struct QueryCompiler {
    var environment = Environment()
    var diagnositics = Diagnostics()
    var schema: Schema
    
    private(set) var inputs: [QueryInput] = []
    
    public init(schema: Schema) {
        self.schema = schema
    }
    
    public mutating func compile(_ source: String) throws -> (CompiledQuery, Diagnostics) {
        return try compile(SelectStmtParser().parse(source))
    }
    
    mutating func compile(_ select: SelectStmt) throws -> (CompiledQuery, Diagnostics) {
        switch select.selects.value {
        case .single(let select):
            let result = try compile(select)
            return (result, diagnositics)
        case .compound:
            fatalError()
        }
    }
    
    private mutating func check(_ expression: Expression) throws -> Ty {
        var typeChecker = TypeChecker(env: environment)
        var (solution, diagnostics) = typeChecker.check(expression)
        diagnositics.add(contentsOf: diagnostics)
        inputs.append(contentsOf: solution.allNames.map { QueryInput(name: $0.0, type: $0.1) })
        return solution.type
    }
    
    private mutating func compile(_ select: SelectCore) throws -> CompiledQuery {
        switch select {
        case .select(let select):
            return try compile(select)
        case .values:
            fatalError()
        }
    }
    
    private mutating func compile(_ select: SelectCore.Select) throws -> CompiledQuery {
        switch select.from {
        case .tableOrSubqueries(let t):
            for table in t {
                try compile(table)
            }
        case .join(let joinClause):
            try compile(joinClause)
        case nil:
            break
        }
        
        let output = try compile(select.columns)
        
        if let whereExpr = select.where {
            let type = try check(whereExpr)
            
            if type != .bool && type != .integer {
                diagnositics.add(.init(
                    "WHERE clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                    at: whereExpr.range
                ))
            }
        }
        
        if let groupBy = select.groupBy {
            for expression in groupBy.expressions {
                _ = try check(expression)
            }
            
            if let having = groupBy.having {
                let type = try check(having)
                
                if type != .bool && type != .integer {
                    diagnositics.add(.init(
                        "HAVING clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                        at: having.range
                    ))
                }
            }
        }
        
        return CompiledQuery(inputs: inputs, output: output)
    }
    
    private mutating func compile(_ resultColumns: [ResultColumn]) throws -> Ty {
        var columns: OrderedDictionary<Substring, Ty> = [:]
        
        for resultColumn in resultColumns {
            switch resultColumn {
            case .expr(let expr, let alias):
                var typeChecker = TypeChecker(env: environment)
                var (solution, diag) = typeChecker.check(expr)
                inputs.append(contentsOf: solution.allNames.map { QueryInput(name: $0.0, type: $0.1) })
                diagnositics.add(contentsOf: diag)
                
                let name = alias?.value ?? solution.lastName
                
                // Name will default to stringified expression, this is what SQLite actually
                // does, but we require one for.
                columns[alias?.value ?? solution.lastName ?? "__name_required__"] = solution.type
                
                if name == nil {
                    diagnositics.add(.init(
                        "Column name required, add via 'AS'",
                        at: expr.range,
                        suggestion: .append("AS \(Diagnostic.placeholder(name: "name"))")
                    ))
                }
            case .all(let tableName):
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
    
    private mutating func compile(_ joinClause: JoinClause) throws {
        try compile(joinClause.tableOrSubquery)
        
        for join in joinClause.joins {
            try compile(join)
        }
    }
    
    private mutating func compile(_ join: JoinClause.Join) throws {
        switch join.constraint {
        case .on(let expression):
            try compile(join.tableOrSubquery, joinOp: join.op)
            
            let type = try check(expression)
            
            if type != .bool && type != .integer {
                diagnositics.add(.init(
                    "JOIN clause should return a 'BOOL' or 'INTEGER', got '\(type)'",
                    at: expression.range
                ))
            }
        case .using(let columns):
            try compile(join.tableOrSubquery, joinOp: join.op, columns: columns.reduce(into: [], { $0.insert($1.value) }))
        case .none:
            try compile(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func compile(
        _ tableOrSubquery: TableOrSubquery,
        joinOp: JoinOperator? = nil,
        columns usedColumns: Set<Substring> = []
    ) throws {
        switch tableOrSubquery {
        case let .table(table):
            let tableName = TableName(schema: table.schema, name: table.name)
            
            guard let tableTy = schema[tableName.name.value] else {
                // TODO: Add diag
                environment.insert(table.name.value, ty: .error)
                return
            }
            
            guard case let .row(.named(columns)) = tableTy else {
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
                ty: isOptional ? .optional(tableTy) : tableTy
            )
            
            for column in columns where usedColumns.isEmpty || usedColumns.contains(column.key) {
                environment.insert(column.key, ty: isOptional ? .optional(column.value) : column.value)
            }
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            var compiler = QueryCompiler(schema: schema)
            let (result, diags) = try compiler.compile(selectStmt)
            
            diagnositics.add(contentsOf: diags)
            
            inputs.append(contentsOf: result.inputs)
            
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
            try compile(joinClause)
        case .subTableOrSubqueries:
            fatalError()
        }
    }
}
