//
//  ForeignKeyClauseParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses out a foreign key clause for column definition.
///
/// Example:
/// REFERENCES user(id) ON DELETE CASCADE
/// REFERENCES user(id) ON DELETE SET NULL
///
/// https://www.sqlite.org/syntax/foreign-key-clause.html
struct ForeignKeyClauseParser: Parser {
    func parse(state: inout ParserState) throws -> ForeignKeyClause {
        try state.take(.references)
        
        let table = try SymbolParser()
            .parse(state: &state)
        
        let columns = try SymbolParser()
            .commaSeparated()
            .inParenthesis()
            .parse(state: &state)
        
        let action = try parseAction(state: &state)
        
        return ForeignKeyClause(
            foreignTable: table,
            foreignColumns: columns,
            action: action
        )
    }
    
    private func parseAction(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Action {
        let token = try state.next()
        
        switch token.kind {
        case .on:
            let on: ForeignKeyClause.On = try LookupParser([.delete: .delete, .update: .update])
                .parse(state: &state)
            
            return .onDo(on, try parseOnDeleteOrUpdateAction(state: &state))
        case .match:
            let name = try SymbolParser()
                .parse(state: &state)
            
            let action = try parseAction(state: &state)
            
            return .match(name, action)
        case .not:
            try state.take(.deferrable)
            return .notDeferrable(try parseDeferrable(state: &state))
        case .deferrable:
            return .notDeferrable(try parseDeferrable(state: &state))
        default:
            throw ParsingError.expected(.on, .match, .not, .deferrable, at: token.range)
        }
    }
    
    /// Parses out the action to be performed on an `ON` clause
    private func parseOnDeleteOrUpdateAction(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Do {
        let token = try state.next()
        
        switch token.kind {
        case .set:
            let token = try state.next()
            switch token.kind {
            case .null: return .setNull
            case .default: return .setDefault
            default: throw ParsingError.expected(.null, .default, at: token.range)
            }
        case .cascade:
            return .cascade
        case .restrict:
            return .restrict
        case .no:
            try state.take(.action)
            return .noAction
        default: throw ParsingError.expected(.set, .cascade, .restrict, .no, at: token.range)
        }
    }
    
    private func parseDeferrable(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Deferrable {
        try state.take(.initially)
        return try LookupParser([
            .deferred: .initiallyDeferred,
            .immediate: .initiallyImmediate
        ])
        .parse(state: &state)
    }
}
