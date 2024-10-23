//
//  SymbolParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses a symbol, this can be a column name or any sort of non keyword
struct SymbolParser: Parser {
    func parse(state: inout ParserState) throws -> Identifier {
        let token = try state.take()
        
        guard case let .symbol(symbol) = token.kind else {
            throw ParsingError.expectedSymbol(at: token.range)
        }
        
        return Identifier(name: symbol, range: token.range)
    }
}

extension Substring: Parsable {
    static let parser = SymbolParser()
}
