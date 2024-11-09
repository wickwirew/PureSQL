//
//  OrderParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Parses ASC, DESC if any. Will default to ASC if none
struct OrderParser: Parser {
    func parse(state: inout ParserState) throws -> Order {
        if try state.take(if: .asc) {
            return .asc
        } else if try state.take(if: .desc) {
            return .desc
        } else {
            return .asc
        }
    }
}
