//
//  InserStmtParser.swift
//
//
//  Created by Wes Wickwire on 11/12/24.
//



struct InserStmtParser: Parser {
    func parse(state: inout ParserState) throws -> InsertStmt {
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
    
    private func parseAction(state: inout ParserState) throws -> InsertStmt.Action {
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
    
    private func parseValues(state: inout ParserState) throws -> InsertStmt.Values {
        if try state.take(if: .default) {
            try state.consume(.values)
            return .defaultValues
        } else {
            return try .select(SelectStmtParser().parse(state: &state), nil)
        }
    }
}


//struct UpsertClauseParser: Parser {
//    func parse(state: inout ParserState) throws -> UpsertClause {
//        
//    }
//}
