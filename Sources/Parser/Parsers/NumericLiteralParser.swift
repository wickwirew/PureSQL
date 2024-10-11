//
//  NumericLiteralParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// https://www.sqlite.org/syntax/numeric-literal.html
struct NumericLiteralParser: Parser {
    func parse(state: inout ParserState) throws -> Numeric {
        let token = try state.take()
        
        switch token.kind {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        case .hex(let value):
            return Double(value)
        default:
            throw ParsingError.expectedNumeric(at: token.range)
        }
    }
}
