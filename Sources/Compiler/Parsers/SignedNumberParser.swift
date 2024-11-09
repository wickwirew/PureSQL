//
//  SignedNumberParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// https://www.sqlite.org/syntax/signed-number.html
struct SignedNumberParser: Parser {
    func parse(state: inout ParserState) throws -> SignedNumber {
        let token = try state.take()
        
        switch token.kind {
        case .double(let value):
            return value
        case .int(let value):
            return SignedNumber(value)
        case .hex(let value):
            return SignedNumber(value)
        case .plus:
            return try NumericLiteralParser()
                .parse(state: &state)
        case .minus:
            return try -NumericLiteralParser()
                .parse(state: &state)
        default:
            throw ParsingError.expectedNumeric(at: token.range)
        }
    }
}
