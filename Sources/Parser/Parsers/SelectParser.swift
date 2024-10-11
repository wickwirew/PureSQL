//
//  SelectParser.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

import Schema

struct SelectParser: Parser {
    func parse(state: inout ParserState) throws -> SelectStatement {
        let distinct = try parseDistinct(state: &state)
        fatalError()
    }
    
    private func parseDistinct(state: inout ParserState) throws -> Bool {
        if try state.take(if: .distinct) {
            return true
        } else if try state.take(if: .all) {
            return false
        } else {
            return false
        }
    }
}

struct SelectStatement {
    let distinct: Bool
}
