//
//  CreateTableParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema
import OrderedCollections

struct CreateTableParser: Parser {
    func parse(state: inout ParserState) throws -> CreateTableStatement {
        try state.consume(.create)
        let isTemporary = try state.take(if: .temp, or: .temporary)
        try state.consume(.table)
        
        let ifNotExists = try state.take(if: .if)
        if ifNotExists {
            try state.consume(.not)
            try state.consume(.exists)
        }
        
        if state.is(of: .as) {
            fatalError("Implement SELECT statement")
        } else {
            let (schema, table) = try TableAndSchemaNameParser()
                .parse(state: &state)
            
            let columns: OrderedDictionary<IdentifierSyntax, ColumnDef> = try ColumnDefinitionParser()
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
}
