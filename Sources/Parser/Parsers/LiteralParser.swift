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
        
        let kind: LiteralExpr.Kind = switch token.kind {
        case .double(let value): .numeric(value, isInt: false)
        case .int(let value): .numeric(Double(value), isInt: true)
        case .hex(let value): .numeric(Double(value), isInt: true)
        case .string(let value): .string(value)
        case .true: .true
        case .false: .false
        case .currentDate: .currentDate
        case .currentTime: .currentTime
        case .currentTimestamp: .currentTimestamp
        default: throw ParsingError(description: "Invalid Literal '\(token)'", sourceRange: token.range)
        }
        
        return LiteralExpr(kind: kind, range: token.range)
    }
}

extension LiteralExpr: Parsable {
    static var parser = LiteralParser()
}
