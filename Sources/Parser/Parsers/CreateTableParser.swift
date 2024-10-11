//
//  CreateTableParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema
import OrderedCollections

public struct CreateTableParser: Parser {
    public init() {}
    public func parse(state: inout ParserState) throws -> CreateTableStatement {
        try state.take(.create)
        let isTemporary = try state.take(if: .temp, or: .temporary)
        try state.take(.table)
        
        let ifNotExists = try state.take(if: .if)
        if ifNotExists {
            try state.take(.not)
            try state.take(.exists)
        }
        
        if state.is(of: .as) {
            fatalError("Implement SELECT statement")
        } else {
            let (schema, table) = try parseSchemaAndTable(state: &state)
            
            let columns: OrderedDictionary<Substring, ColumnDef> = try ColumnDefinitionParser()
                .commaSeparated()
                .inParenthesis()
                .parse(state: &state)
                .reduce(into: [:], { $0[$1.name] = $1 })
            
            let options = try TableOptionsParser()
                .parse(state: &state)
            
            return CreateTableStatement(
                name: table,
                schemaName: schema,
                isTemporary: isTemporary,
                onlyIfExists: ifNotExists,
                kind: .columns(columns),
                constraints: [],
                options: options
            )
        }
    }
    
    func parseSchemaAndTable(
        state: inout ParserState
    ) throws -> (schema: Substring?, table: Substring) {
        let symbol = SymbolParser()
        
        let first = try symbol.parse(state: &state)
        
        if try state.take(if: .dot) {
            return (first, try symbol.parse(state: &state))
        } else {
            return (nil, first)
        }
    }
}
