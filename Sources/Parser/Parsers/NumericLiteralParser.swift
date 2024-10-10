//
//  NumericLiteralParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

struct NumericLiteralParser: Parser {
    func parse(state: inout ParserState) throws -> Numeric {
        let token = try state.next()
        
        guard case let .numeric(num) = token.kind else {
            throw ParsingError.expectedNumeric(at: token.range)
        }
        
        return num
    }
}
