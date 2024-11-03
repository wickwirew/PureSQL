//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import Schema

struct QuerySource {
    var name: Substring
    var tableName: Substring
    var fields: [Substring: QueryField]
    var joinOp: JoinOperator?
    var isError = false
    
    static let error = QuerySource(
        name: "<<error>>",
        tableName: "<<error>>",
        fields: [:],
        joinOp: nil,
        isError: true
    )
}

struct QueryField: Equatable {
    var name: Substring
    var type: Ty
}

struct CompiledQuery {
    var inputs: [QueryField]
    var outputs: [QueryField]
}

struct QueryCompiler {
    var environment: Environment
    var diagnositics: Diagnostics
    var schema: DatabaseSchema
    
    mutating func compile(_ select: SelectStmt) throws -> CompiledQuery {
        switch select.selects.value {
        case .single(let select):
            return try compile(select)
        case .compound:
            fatalError()
        }
    }
    
    private mutating func compile(_ select: SelectCore) throws -> CompiledQuery {
        switch select {
        case .select(let select):
            return try compile(select)
        case .values(let values):
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
        
        var typeChecker = TypeChecker(scope: environment)
        var inputs: [QueryField] = []
        var outputs: [QueryField] = []
        
        for column in select.columns {
            switch column {
            case .expr(let expr, let `as`):
                var solution = try typeChecker.check(expr)
                outputs.append(.init(name: `as`?.name ?? solution.lastName ?? "TODO", type: solution.type))
                inputs.append(contentsOf: solution.allNames.map { QueryField(name: $0.0, type: $0.1) })
            case .all(let tableName):
                if let tableName {
                    if let table = environment.sources[.init(schema: .main, name: tableName)] {
                        outputs.append(contentsOf: table.fields.values)
                    } else {
                        diagnositics.add(.init("Table '\(tableName)' does not exist", at: tableName.range))
                    }
                } else {
                    for table in environment.sources.values {
                        outputs.append(contentsOf: table.fields.values)
                    }
                }
            }
        }
        
        return CompiledQuery(inputs: inputs, outputs: outputs)
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
            // TODO: Check Expression
            try compile(join.tableOrSubquery, joinOp: join.op)
        case .using(let columns):
            try compile(join.tableOrSubquery, joinOp: join.op, columns: Set(columns))
        case .none:
            try compile(join.tableOrSubquery, joinOp: join.op)
        }
    }
    
    private mutating func compile(
        _ tableOrSubquery: TableOrSubquery,
        joinOp: JoinOperator? = nil,
        columns: Set<Identifier> = []
    ) throws {
        switch tableOrSubquery {
        case let .table(table):
            let tableName = TableName(schema: table.schema, name: table.name)
            
            guard let tableShema = schema.tables[tableName] else {
                environment.include(name: tableName, source: .error)
                return
            }
            
            let source = QuerySource(
                name: table.name.name,
                tableName: table.name.name,
                fields: tableShema.columns
                    .filter { columns.isEmpty || columns.contains($0.key) }
                    .reduce(into: [:]) { $0[$1.key.name] = .init(name: $1.value.name.name, type: .nominal($1.value.type)) },
                joinOp: joinOp
            )
            
            environment.include(name: tableName, source: source)
        case let .tableFunction(schema, table, args, alias):
            fatalError()
        case let .subquery(selectStmt):
            fatalError()
        case let .join(joinClause):
            try compile(joinClause)
        case let .subTableOrSubqueries(array, alias):
            fatalError()
        }
    }
}



