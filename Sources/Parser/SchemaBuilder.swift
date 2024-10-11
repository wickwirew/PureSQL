//
//  SchemaBuilder.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

import Schema
import OrderedCollections

public struct DatabaseSchema {
    public let tables: OrderedDictionary<Substring, Table>
}

public struct SchemaBuilder: StatementVisitor {
    public static func build(from source: String) throws -> DatabaseSchema {
        var state = try ParserState(Lexer(source: source))
        
        let statements = try StmtParser()
            .semiColonSeparated()
            .parse(state: &state)
        
        return try build(from: statements)
    }
    
    public static func build(from statements: [any Statement]) throws -> DatabaseSchema {
        let builder = SchemaBuilder()
        var schema = DatabaseSchema(tables: [:])
        
        for statement in statements {
            schema = try statement.accept(visitor: builder, with: schema)
        }
        
        return schema
    }
    
    public func visit(statement: EmptyStatement, with input: DatabaseSchema) throws -> DatabaseSchema {
        return input
    }
    
    public func visit(statement: CreateTableStatement, with input: DatabaseSchema) throws -> DatabaseSchema {
        guard case let .columns(columns) = statement.kind else {
            fatalError("Not implemented")
        }
        
        let table = Table(
            name: statement.name,
            schemaName: statement.schemaName,
            isTemporary: statement.isTemporary,
            columns: columns,
            constraints: statement.constraints,
            options: statement.options
        )
        
        return DatabaseSchema(
            tables: input.tables.merging([table.name: table], uniquingKeysWith: { _, t in t })
        )
    }
    
    public func visit(statement: AlterTableStatement, with input: DatabaseSchema) throws -> DatabaseSchema {
        guard var table = input.tables[statement.name] else {
            fatalError()
        }
        
        switch statement.kind {
        case .rename(let newName):
            table.name = newName
        case .renameColumn(let oldName, let newName):
            guard var column = table.columns[oldName] else {
                fatalError("Does not exist")
            }
            
            column.name = newName
        case .addColumn(let column):
            table.columns[column.name] = column
        case .dropColumn(let column):
            table.columns.removeValue(forKey: column)
        }
        
        return DatabaseSchema(
            tables: input.tables.merging([table.name: table], uniquingKeysWith: { _, t in t })
        )
    }
}
