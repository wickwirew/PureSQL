//
//  TableOptionsParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

/// https://www.sqlite.org/syntax/table-options.html
struct TableOptionsParser: Parser {
    func parse(state: inout ParserState) throws -> TableOptions {
        var options: TableOptions = []
        
        repeat {
            switch state.current.kind {
            case .without:
                try state.skip()
                try state.consume(.rowid)
                options = options.union(.withoutRowId)
            case .strict:
                try state.skip()
                options = options.union(.strict)
            case .eof, .semiColon:
                return options
            default:
                throw ParsingError.expected(.without, .strict, at: state.current.range)
            }
        } while try state.take(if: .comma)
        
        return options
    }
}
