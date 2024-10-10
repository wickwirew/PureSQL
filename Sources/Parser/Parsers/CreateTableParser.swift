//
//  CreateTableParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

struct CreateTableParser: Parser {
    func parse(state: inout ParserState) throws -> CreateTableStmt {
        try state.take(.create)
        let isTemporary = try state.take(if: .temp, or: .temporary)
        try state.take(.table)
        
        let ifNotExists = try state.next(if: .if)
        if ifNotExists {
            try state.take(.not)
            try state.take(.exists)
        }
        
        if state.is(of: .as) {
            fatalError("Implement SELECT statement")
        } else {
            let (schema, table) = try SchemaAndTableNameParser()
                .parse(state: &state)
            
            let columns = try ColumnDefinitionParser()
                .commaSeparated()
                .inParenthesis()
                .parse(state: &state)
                .reduce(into: [:], { $0[$1.name] = $1 })
            
            return CreateTableStmt(
                name: table,
                schemaName: schema,
                isTemporary: isTemporary,
                onlyIfExists: ifNotExists,
                kind: .columns(columns),
                constraints: [],
                options: []
            )
        }
    }
}

struct SchemaAndTableNameParser: Parser {
    func parse(state: inout ParserState) throws -> (schema: Substring?, table: Substring) {
        let symbol = SymbolParser()
        
        let first = try symbol.parse(state: &state)
        
        if try state.next(if: .dot) {
            return (first, try symbol.parse(state: &state))
        } else {
            return (nil, first)
        }
    }
}

/// Parses a column definition that can be in a create table
/// or an alter statement.
///
/// https://www.sqlite.org/syntax/column-def.html
struct ColumnDefinitionParser: Parser {
    func parse(state: inout ParserState) throws -> ColumnDef {
        let name = try SymbolParser().parse(state: &state)
        let type = try TyParser().parse(state: &state)
        let constraints = try ColumnConstraintParser()
            .collect(until: [.comma, .closeParen])
            .parse(state: &state)
        return ColumnDef(name: name, type: type, constraints: constraints)
    }
}

struct SignedNumberParser: Parser {
    func parse(state: inout ParserState) throws -> SignedNumber {
        let token = try state.next()
        
        guard case let .numeric(num) = token.kind else {
            throw ParsingError.expectedNumeric(at: token.range)
        }
        
        return num
    }
}

/// Parses a primary key constraint on a column definition
/// https://www.sqlite.org/syntax/column-constraint.html
struct ColumnConstraintParser: Parser {
    let name: Substring?
    
    init(name: Substring? = nil) {
        self.name = name
    }
    
    func parse(state: inout ParserState) throws -> ColumnConstraint {
        switch state.peek.kind {
        case .constraint:
            try state.skip()
            
            let name = try SymbolParser()
                .parse(state: &state)
            
            return try ColumnConstraintParser(name: name)
                .parse(state: &state)
        case .primary:
            return try ColumnPrimaryKeyConstraintParser(name: name)
                .parse(state: &state)
        case .not:
            try state.skip()
            try state.take(.null)
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
            if state.peek.kind == .openParen {
                let expr = try ExprParser()
                    .inParenthesis()
                    .parse(state: &state)
                return ColumnConstraint(name: name, kind: .default(.expr(expr)))
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
            try state.take(.always)
            try state.take(.as)
            
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
            throw ParsingError.unexpectedToken(of: state.peek.kind, at: state.peek.range)
        }
    }
    
    private func parseGeneratedKind(
        state: inout ParserState
    ) throws -> ColumnConstraint.GeneratedKind? {
        try LookupParser([.stored: .stored, .virtual: .virtual])
            .parse(state: &state)
    }
}

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


/// Parses a primary key constraint on a column definition
/// https://www.sqlite.org/syntax/column-constraint.html
struct ColumnPrimaryKeyConstraintParser: Parser {
    let name: Substring?
    
    func parse(state: inout ParserState) throws -> ColumnConstraint {
        try state.take(.primary)
        try state.take(.key)
        
        let order = try OrderParser()
            .parse(state: &state)
        
        let conflictClause = try ConfictClauseParser()
            .parse(state: &state)
        
        let autoincrement = try state.next(if: .autoincrement)
        
        return ColumnConstraint(
            name: name,
            kind: .primaryKey(order: order, conflictClause, autoincrement: autoincrement)
        )
    }
}

struct LiteralParser: Parser {
    func parse(state: inout ParserState) throws -> Literal {
        let token = try state.next()
        
        // TODO: Rest of literals
        switch token.kind {
        case .numeric(let value): return .numeric(value)
        case .string(let value): return .string(value)
        default: throw ParsingError(description: "Invalid Literal '\(token)'", sourceRange: token.range)
        }
    }
}

struct ExprParser: Parser {
    func parse(state: inout ParserState) throws -> Expr {
        // TODO
        return Expr()
    }
}

/// Parses a conflict clause.
///
/// Example:
/// ON CONFLICT IGNORE
///
/// https://www.sqlite.org/syntax/conflict-clause.html
struct ConfictClauseParser: Parser {
    func parse(state: inout ParserState) throws -> ConfictClause {
        guard state.peek.kind == .on else { return .none }
        
        try state.take(.on)
        try state.take(.conflict)
        
        let token = try state.next()
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

struct TyParser: Parser {
    func parse(state: inout ParserState) throws -> Ty {
        let range = state.range
        let name = try SymbolParser().parse(state: &state)
        
        if state.is(of: .openParen) {
            let numbers = try SignedNumberParser()
                .commaSeparated()
                .inParenthesis()
                .parse(state: &state)
            
            let first = numbers.first
            let second = numbers.count > 1 ? numbers[1] : nil
            return try tyOrThrow(at: range, name: name, with: first, and: second)
        } else {
            return try tyOrThrow(at: range, name: name)
        }
    }
    
    func tyOrThrow(
        at range: Range<String.Index>,
        name: Substring,
        with first: Numeric? = nil,
        and second: Numeric? = nil
    ) throws -> Ty {
        guard let ty = Ty(name: name, with: first, and: second) else {
            throw ParsingError.unknown(type: name, at: range)
        }
        
        return ty
    }
}


struct TakeIfParser<Inner: Parser>: Parser {
    let required: Token.Kind
    let inner: Inner
    
    func parse(state: inout ParserState) throws -> Inner.Output? {
        guard state.is(of: required) else { return nil }
        return try inner.parse(state: &state)
    }
}

extension Parser {
    func take(if kind: Token.Kind) -> TakeIfParser<Self> {
        return TakeIfParser(required: kind, inner: self)
    }
}

struct CollectIfParser<Inner: Parser>: Parser {
    let tokens: Set<Token.Kind>
    let inner: Inner
    
    func parse(state: inout ParserState) throws -> [Inner.Output] {
        guard tokens.contains(state.peek.kind) else { return [] }
        
        var elements: [Inner.Output] = []
        
        repeat {
            try elements.append(inner.parse(state: &state))
        } while tokens.contains(state.peek.kind)
        
        return elements
    }
}

extension Parser {
    func collect(if kinds: Set<Token.Kind>) -> CollectIfParser<Self> {
        return CollectIfParser(tokens: kinds, inner: self)
    }
}

struct CollectUntilParser<Inner: Parser>: Parser {
    let tokens: Set<Token.Kind>
    let inner: Inner
    
    func parse(state: inout ParserState) throws -> [Inner.Output] {
        guard !tokens.contains(state.peek.kind) else { return [] }
        
        var elements: [Inner.Output] = []
        
        repeat {
            try elements.append(inner.parse(state: &state))
        } while !tokens.contains(state.peek.kind)
        
        return elements
    }
}

extension Parser {
    func collect(until kinds: Set<Token.Kind>) -> CollectUntilParser<Self> {
        return CollectUntilParser(tokens: kinds, inner: self)
    }
}

struct MapParser<Base: Parser, Output>: Parser {
    let base: Base
    let transform: (Base.Output) throws -> Output
    
    func parse(state: inout ParserState) throws -> Output {
        try transform(base.parse(state: &state))
    }
}

extension Parser {
    func map<New>(_ transform: @escaping (Output) throws -> New) -> MapParser<Self, New> {
        return MapParser(base: self, transform: transform)
    }
}

struct LookupParser<Output>: Parser {
    let lookup: [Token.Kind: Output]
    
    init(_ lookup: [Token.Kind : Output]) {
        self.lookup = lookup
    }
    
    func parse(state: inout ParserState) throws -> Output {
        let token = try state.next()
        
        guard let output = lookup[token.kind] else {
            throw ParsingError.expected(Array(lookup.keys), at: token.range)
        }
        
        return output
    }
}
