//
//  ColumnConstraintParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses a primary key constraint on a column definition
/// https://www.sqlite.org/syntax/column-constraint.html
struct ColumnConstraintParser: Parser {
    let name: Identifier?
    
    init(name: Identifier? = nil) {
        self.name = name
    }
    
    func parse(state: inout ParserState) throws -> ColumnConstraint {
        switch state.current.kind {
        case .constraint:
            try state.skip()
            
            let name = try SymbolParser()
                .parse(state: &state)
            
            return try ColumnConstraintParser(name: name)
                .parse(state: &state)
        case .primary:
            return try parsePrimaryKey(state: &state)
        case .not:
            try state.skip()
            try state.consume(.null)
            let conflictClause = try ConfictClauseParser().parse(state: &state)
            return ColumnConstraint(name: name, kind: .notNull(conflictClause))
        case .unique:
            try state.skip()
            let conflictClause = try ConfictClauseParser().parse(state: &state)
            return ColumnConstraint(name: name, kind: .unique(conflictClause))
        case .check:
            try state.skip()
            let expr = try ExprParser()
                .inParenthesis()
                .parse(state: &state)
            return ColumnConstraint(name: name, kind: .check(expr))
        case .default:
            try state.skip()
            if state.current.kind == .openParen {
                let expr = try ExprParser()
                    .inParenthesis()
                    .parse(state: &state)
                return ColumnConstraint(name: name, kind: .default(expr))
            } else {
                let literal = try LiteralParser()
                    .parse(state: &state)
                return ColumnConstraint(name: name, kind: .default(.literal(literal)))
            }
        case .collate:
            try state.skip()
            let collation = try SymbolParser().parse(state: &state)
            return ColumnConstraint(name: name, kind: .collate(collation))
        case .references:
            let fk = try ForeignKeyClauseParser()
                .parse(state: &state)
            return ColumnConstraint(name: name, kind: .foreignKey(fk))
        case .generated:
            try state.skip()
            try state.consume(.always)
            try state.consume(.as)
            
            let expr = try ExprParser()
                .inParenthesis()
                .parse(state: &state)
            
            let generated = try parseGeneratedKind(state: &state)
            
            return ColumnConstraint(name: name, kind: .generated(expr, generated))
        case .as:
            let expr = try ExprParser()
                .inParenthesis()
                .parse(state: &state)
            
            let generated = try parseGeneratedKind(state: &state)
            
            return ColumnConstraint(name: name, kind: .generated(expr, generated))
        default:
            throw ParsingError.unexpectedToken(of: state.current.kind, at: state.current.range)
        }
    }
    
    private func parseGeneratedKind(
        state: inout ParserState
    ) throws -> ColumnConstraint.GeneratedKind? {
        try LookupParser([.stored: .stored, .virtual: .virtual])
            .parse(state: &state)
    }
    
    private func parsePrimaryKey(
        state: inout ParserState
    ) throws -> ColumnConstraint {
        try state.consume(.primary)
        try state.consume(.key)
        
        let order = try OrderParser()
            .parse(state: &state)
        
        let conflictClause = try ConfictClauseParser()
            .parse(state: &state)
        
        let autoincrement = try state.take(if: .autoincrement)
        
        return ColumnConstraint(
            name: name,
            kind: .primaryKey(order: order, conflictClause, autoincrement: autoincrement)
        )
    }
}
