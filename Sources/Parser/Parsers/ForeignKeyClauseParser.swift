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
            .take(if: .openParen)
            .parse(state: &state)
        
        let actions = try parseActions(state: &state)
        
        return ForeignKeyClause(
            foreignTable: table,
            foreignColumns: columns ?? [],
            actions: actions
        )
    }
    
    private func parseActions(
        state: inout ParserState
    ) throws -> [ForeignKeyClause.Action] {
        guard let action = try parseAction(state: &state) else { return [] }
        
        switch action {
        case .onDo, .match:
            return [action] + (try parseActions(state: &state))
        case .deferrable, .notDeferrable:
            // These cannot have a secondary action
            return [action]
        }
    }
    
    private func parseAction(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Action? {
        switch state.current.kind {
        case .on:
            try state.skip()
            let on: ForeignKeyClause.On = try LookupParser([.delete: .delete, .update: .update])
                .parse(state: &state)
            
            return .onDo(on, try parseOnDeleteOrUpdateAction(state: &state))
        case .match:
            try state.skip()
            let name = try SymbolParser()
                .parse(state: &state)
            
            return .match(name, try parseActions(state: &state))
        case .not:
            try state.skip()
            try state.take(.deferrable)
            return .notDeferrable(try parseDeferrable(state: &state))
        case .deferrable:
            try state.skip()
            return .deferrable(try parseDeferrable(state: &state))
        default:
            return nil
        }
    }
    
    /// Parses out the action to be performed on an `ON` clause
    private func parseOnDeleteOrUpdateAction(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Do {
        let token = try state.take()
        
        switch token.kind {
        case .set:
            let token = try state.take()
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
    ) throws -> ForeignKeyClause.Deferrable? {
        switch state.current.kind {
        case .initially:
            try state.skip()
            let token = try state.take()
            switch token.kind {
            case .deferred: return .initiallyDeferred
            case .immediate: return .initiallyImmediate
            default: throw ParsingError.expected(.deferred, .immediate, at: token.range)
            }
        default:
            return nil
        }
    }
}
