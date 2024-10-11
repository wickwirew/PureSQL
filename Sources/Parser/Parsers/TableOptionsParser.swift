//
//  TableOptionsParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// https://www.sqlite.org/syntax/table-options.html
struct TableOptionsParser: Parser {
    func parse(state: inout ParserState) throws -> TableOptions {
        var options: TableOptions = []
        
        repeat {
            let token = try state.take()
            
            switch token.kind {
            case .without:
                try state.take(.rowid)
                options = options.union(.withoutRowId)
            case .strict:
                options = options.union(.strict)
            case .eof:
                return options
            default:
                throw ParsingError.expected(.without, .strict, at: token.range)
            }
        } while try state.take(if: .comma)
        
        return options
    }
}
