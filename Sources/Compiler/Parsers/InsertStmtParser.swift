//
//  InserStmtParser.swift
//
//
//  Created by Wes Wickwire on 11/12/24.
//



struct InserStmtParser: Parser {
    func parse(state: inout ParserState) throws -> InsertStmtSyntax {
        let (cte, cteRecursive) = try parseCte(state: &state)
        let action = try parseAction(state: &state)
        
        let (schema, tableName) = try TableAndSchemaNameParser()
            .parse(state: &state)
        
        let alias = try IdentifierParser()
            .take(if: .as, consume: true)
            .parse(state: &state)
        
        let columns = try IdentifierParser()
            .inParenthesis()
            .take(if: .openParen)
            .parse(state: &state)
        
        fatalError()
    }
    
    private func parseCte(state: inout ParserState) throws -> (CommonTableExpression?, Bool) {
        if try state.take(if: .with) {
            let cteRecursive = try state.take(if: .recursive)
            let cte = try CommonTableExprParser()
                .parse(state: &state)
            return (cte, cteRecursive)
        } else {
            return (nil, false)
        }
    }
    
    private func parseAction(state: inout ParserState) throws -> InsertStmtSyntax.Action {
        let token = try state.take()
        
        switch token.kind {
        case .replace:
            return .replace
        case .insert:
            if try state.take(if: .or) {
                let token = try state.take()
                switch token.kind {
                case .abort: return .insert(.abort)
                case .fail: return .insert(.fail)
                case .ignore: return .insert(.ignore)
                case .replace: return .insert(.replace)
                case .rollback: return .insert(.rollback)
                default:
                    throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
                }
            } else {
                return .insert(nil)
            }
        default:
            throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
        }
    }
    
    private func parseValues(state: inout ParserState) throws -> InsertStmtSyntax.Values? {
        if try state.take(if: .default) {
            try state.consume(.values)
            return nil
        } else {
            let select = try SelectStmtParser().parse(state: &state)
            let upsertClause = try UpsertClauseParser()
                .take(if: .on, consume: false)
                .parse(state: &state)
            return .init(select: select, upsertClause: upsertClause)
        }
    }
}


struct UpsertClauseParser: Parser {
    func parse(state: inout ParserState) throws -> UpsertClauseSyntax {
        let on = try state.take(.on)
        try state.consume(.conflict)
        
        let conflictTarget = try parseConflictTarget(state: &state)
        
        try state.consume(.do)
        
        if try state.take(if: .nothing) {
            return .init(
                confictTarget: conflictTarget,
                doAction: .nothing,
                range: on.range.lowerBound ..< state.current.range.lowerBound
            )
        }
        
        try state.consume(.update)
        try state.consume(.set)
        
//        let meow = try IdentifierParser()
//            .take(if: .abort)
//            .commaSeparated()
//            .parse(state: &state)
//
        fatalError()
    }
    
    private func parseConflictTarget(state: inout ParserState) throws -> UpsertClauseSyntax.ConflictTarget? {
        fatalError()
    }
}
