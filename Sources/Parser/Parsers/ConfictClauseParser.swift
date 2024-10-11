//
//  ConfictClauseParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses a conflict clause.
///
/// Example:
/// ON CONFLICT IGNORE
///
/// https://www.sqlite.org/syntax/conflict-clause.html
struct ConfictClauseParser: Parser {
    func parse(state: inout ParserState) throws -> ConfictClause {
        guard state.current.kind == .on else { return .none }
        
        try state.take(.on)
        try state.take(.conflict)
        
        let token = try state.take()
        switch token.kind {
        case .rollback: return .rollback
        case .abort: return .abort
        case .fail: return .fail
        case .ignore: return .ignore
        case .replace: return .replace
        default: throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
        }
    }
}
