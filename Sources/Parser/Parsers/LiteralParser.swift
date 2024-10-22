//
//  LiteralParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

struct LiteralParser: Parser {
    func parse(state: inout ParserState) throws -> LiteralExpr {
        let token = try state.take()
        
        switch token.kind {
        case .double(let value): return .numeric(value, isInt: false)
        case .int(let value): return .numeric(Double(value), isInt: true)
        case .hex(let value): return .numeric(Double(value), isInt: true)
        case .string(let value): return .string(value)
        case .true: return .true
        case .false: return .false
        case .currentDate: return .currentDate
        case .currentTime: return .currentTime
        case .currentTimestamp: return .currentTimestamp
        default: throw ParsingError(description: "Invalid Literal '\(token)'", sourceRange: token.range)
        }
    }
}

extension LiteralExpr: Parsable {
    static var parser = LiteralParser()
}
