//
//  LiteralParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

struct LiteralParser: Parser {
    func parse(state: inout ParserState) throws -> Literal {
        let token = try state.take()
        
        switch token.kind {
        case .double(let value): return .numeric(value)
        case .int(let value): return .numeric(Double(value))
        case .hex(let value): return .numeric(Double(value))
        case .string(let value): return .string(value)
        default: throw ParsingError(description: "Invalid Literal '\(token)'", sourceRange: token.range)
        }
    }
}
