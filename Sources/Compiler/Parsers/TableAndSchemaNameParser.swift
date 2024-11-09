//
//  TableAndSchemaNameParser.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

struct TableAndSchemaNameParser: Parser {
    func parse(state: inout ParserState) throws -> (schema: IdentifierSyntax?, table: IdentifierSyntax) {
        let symbol = IdentifierParser()
        
        let first = try symbol.parse(state: &state)
        
        if try state.take(if: .dot) {
            return (first, try symbol.parse(state: &state))
        } else {
            return (nil, first)
        }
    }
}
