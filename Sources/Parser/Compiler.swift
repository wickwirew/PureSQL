//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import Schema
import OrderedCollections

struct QuerySource: Sendable {
    var name: Substring?
    var tableName: Substring?
    var fields: OrderedDictionary<Substring, QueryField>
    var isError = false
    
    static let error = QuerySource(
        name: "<<error>>",
        tableName: "<<error>>",
        fields: [:],
        isError: true
    )
}

struct QueryField: Equatable, CustomStringConvertible, Sendable {
    var name: Substring
    var type: Ty
    
    var description: String {
        return "\(name): \(type)"
    }
}

struct CompiledQuery {
    var inputs: [QueryField]
    var outputs: [Ty]
}

struct QueryCompiler {
    var environment: Environment
    var diagnositics: Diagnostics
    var schema: DatabaseSchema
    
    private(set) var inputs: [QueryField] = []
    private(set) var outputs: [Ty] = []
    
    init(
        environment: Environment,
        diagnositics: Diagnostics,
        schema: DatabaseSchema
    ) {
        self.environment = environment
        self.diagnositics = diagnositics
        self.schema = schema
    }
    
    consuming func compile(_ select: SelectStmt) throws -> CompiledQuery {
        switch select.selects.value {
        case .single(let select):
            return try compile(select)
        case .compound:
            fatalError()
        }
    }
    
    private mutating func check(_ expression: Expression) throws -> Ty {
        var typeChecker = TypeChecker(env: environment)
        let solution = try typeChecker.check(expression)
        diagnositics.add(contentsOf: solution.diagnostics)
        return solution.type
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
        
        for column in select.columns {
            try compile(column)
        }
        
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
        
        return CompiledQuery(inputs: inputs, outputs: outputs)
    }
    
    private mutating func compile(_ resultColumn: ResultColumn) throws {
        switch resultColumn {
        case .expr(let expr, let `as`):
            var typeChecker = TypeChecker(env: environment)
            var solution = try typeChecker.check(expr)
            outputs.append(solution.type)
            inputs.append(contentsOf: solution.allNames.map { QueryField(name: $0.0, type: $0.1) })
        case .all(let tableName):
            if let tableName {
                if let table = environment[tableName.name] {
//                    outputs.append(contentsOf: table.fields.values)
                } else {
                    diagnositics.add(.init("Table '\(tableName)' does not exist", at: tableName.range))
                }
            } else {
//                for table in environment.sources.values {
//                    outputs.append(contentsOf: table.fields.values)
//                }
            }
        }
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
                environment.include(table: table.name.name, source: .error)
                return
            }
            
            let isOptional = switch joinOp {
            case nil, .inner: false
            default: true
            }
            
            let source = QuerySource(
                name: table.name.name,
                tableName: table.name.name,
                fields: tableShema.columns
                    .filter { columns.isEmpty || columns.contains($0.key) }
                    .reduce(into: [:]) { acc, column in
                        let ty: Ty = .nominal(column.value.type.name.name)
                        return acc[column.key.name] = .init(
                            name: column.value.name.name,
                            type: isOptional ? .optional(ty) : ty
                        )
                    }
            )
            
            environment.include(table: table.alias?.name ?? table.name.name, source: source)
        case let .tableFunction(schema, table, args, alias):
            fatalError()
        case let .subquery(selectStmt, alias):
            let compiler = QueryCompiler(
                environment: Environment(),
                diagnositics: Diagnostics(),
                schema: schema
            )
            
//            let result = try compiler.compile(selectStmt)
//            
//            let source = QuerySource(
//                name: nil,
//                tableName: nil,
//                fields: result.outputs.reduce(into: [:], { $0[$1.name] = $1 })
//            )
//            
//            environment.include(subquery: source)
//            inputs.append(contentsOf: result.inputs)
        case let .join(joinClause):
            try compile(joinClause)
        case let .subTableOrSubqueries(array, alias):
            fatalError()
        }
    }
}
