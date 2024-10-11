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
        // TODO
        let token = try state.take()
        
        guard case let .numeric(num) = token.kind else {
            throw ParsingError.expectedNumeric(at: token.range)
        }
        
        return num
    }
}
