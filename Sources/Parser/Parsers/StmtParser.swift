//
//  StmtParser.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

import Schema

public struct StmtParser: Parser {
    public init() {}
    
    public func parse(state: inout ParserState) throws -> any Statement {
        switch (state.current.kind, state.peek.kind) {
        case (.create, .table):
            return try CreateTableParser()
                .parse(state: &state)
        default:
            throw ParsingError.unexpectedToken(of: state.current.kind, at: state.current.range)
        }
    }
}
