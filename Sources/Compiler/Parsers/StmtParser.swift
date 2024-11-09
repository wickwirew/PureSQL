//
//  StmtParser.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

struct StmtParser: Parser {
    func parse(state: inout ParserState) throws -> any Statement {
        switch (state.current.kind, state.peek.kind) {
        case (.create, .table):
            return try CreateTableParser()
                .parse(state: &state)
        case (.alter, .table):
            return try AlterTableParser()
                .parse(state: &state)
        case (.select, _):
            return try SelectStmtParser()
                .parse(state: &state)
        case (.semiColon, _), (.eof, _):
            try state.skip()
            return EmptyStatement()
        default:
            throw ParsingError.unexpectedToken(of: state.current.kind, at: state.current.range)
        }
    }
}
