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
    var outputs: [QueryField]
}

struct QueryCompiler {
    var environment: Environment
    var diagnositics: Diagnostics
    var schema: Schema
    
    private(set) var inputs: [QueryField] = []
    private(set) var outputs: [QueryField] = []
    
    init(
        environment: Environment,
        diagnositics: Diagnostics,
        schema: Schema
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
        let (solution, diagnostics) = typeChecker.check(expression)
        diagnositics.add(contentsOf: diagnostics)
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
            var (solution, diag) = typeChecker.check(expr)
            outputs.append(QueryField(name: `as`?.value ?? "TODO", type: solution.type))
            inputs.append(contentsOf: solution.allNames.map { QueryField(name: $0.0, type: $0.1) })
            diagnositics.add(contentsOf: diag)
        case .all(let tableName):
            if let tableName {
                if let table = environment[tableName.value]?.type {
                    guard case let .row(.named(columns)) = table else {
                        return diagnositics.add(.init("'\(tableName)' is not a table", at: tableName.range))
                    }
                    
                    for (name, type) in columns {
                        outputs.append(QueryField(name: name, type: type))
                    }
                } else {
                    diagnositics.add(.init("Table '\(tableName)' does not exist", at: tableName.range))
                }
            } else {
                // TODO: Find better way to do this than to iterate through the env
                for (name, type) in environment {
                    switch type.type {
                    case .nominal, .optional:
                        outputs.append(QueryField(name: name, type: type.type))
                    default:
                        continue
                    }
                }
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
                environment.include(table: table.name.value, source: .error)
                return
            }
            
            guard case let .row(.named(columns)) = tableTy else {
                // TODO: Add diag
                environment.include(table: table.name.value, source: .error)
                return
            }

            environment.insert(table.alias?.value ?? table.name.value, ty: tableTy)
            
            for column in columns where usedColumns.isEmpty || usedColumns.contains(column.key) {
                environment.insert(column.key, ty: column.value)
            }
        case .tableFunction:
            fatalError()
        case let .subquery(selectStmt, alias):
            let compiler = QueryCompiler(
                environment: Environment(),
                diagnositics: Diagnostics(),
                schema: schema
            )
            
            let result = try compiler.compile(selectStmt)
            
            inputs.append(contentsOf: result.inputs)
            
            environment.insert(
                alias?.value ?? "TODO",
                ty: .row(.named(result.outputs.reduce(into: [:], { $0[$1.name] = $1.type })))
            )
            
            for output in result.outputs {
                environment.insert(output.name, ty: output.type)
            }
        case let .join(joinClause):
            try compile(joinClause)
        case .subTableOrSubqueries:
            fatalError()
        }
    }
}
