//
//  ExprParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

struct ExprParser: Parser {
    let precedence: Operator.Precedence
    
    init(precedence: Operator.Precedence = 0) {
        self.precedence = precedence
    }
    
    func parse(state: inout ParserState) throws -> Expression {
        guard let expr = try MaybeExprParser(precedence: precedence).parse(state: &state) else {
            throw ParsingError(description: "Expected Expression", sourceRange: state.range)
        }
        
        return expr
    }
}

/// https://www.sqlite.org/syntax/expr.html
struct MaybeExprParser: Parser {
    let precedence: Operator.Precedence
    
    func parse(state: inout ParserState) throws -> Expression? {
        if let param = try BindParameter.parse(state: &state) {
            return .bindParameter(param)
        } else if let column = try QualifiedColumnParser().parse(state: &state) {
            return .column(schema: column.schema, table: column.table, column: column.column)
        } else if let op = try Operator.parse(state: &state) {
            return try .prefix(op, ExprParser(precedence: precedence).parse(state: &state))
        } else {
            return nil
        }
    }
}

//struct InfixExprParser: Parser {
//    let lhs: Expression
//    let op: Operator
//
//    func parse(state: inout ParserState) throws -> Expression {
//        var nextOpState = try state.skippingOne()
//        guard let nextOp = try OperatorParser(context: .infixOrPostfix)
//            .parse(state: &nextOpState) else { reutrn lhs}
//
//        if nextOp?.precedence
//    }
//}

struct PrefixOperatorParser: Parser {
    func parse(state: inout ParserState) throws -> Operator? {
        nil
    }
}

struct OperatorParser: Parser {
    func parse(state: inout ParserState) throws -> Operator? {
        guard let op = Operator
            .guess(for: state.current.kind, after: state.peek.kind) else { return nil }
        
        try op.skip(state: &state)
        
        switch op {
        case .tilde, .collate, .concat, .arrow, .doubleArrow, .multiply, .divide,
             .cast, .plus, .minus, .bitwiseAnd, .bitwuseOr, .shl, .shr, .escape,
             .lt, .gt, .lte, .gte, .eq, .eq2, .neq, .neq2, .match, .like, .regexp,
             .glob, .or, .and, .between, .not, .in, .isnull, .notnull, .notNull, .isDistinctFrom:
            return op
        case .`is`:
            if try state.take(if: .distinct) {
                try state.take(.from)
                return .isDistinctFrom
            } else {
                return op
            }
        case .isNot:
            if try state.take(if: .distinct) {
                try state.take(.from)
                return .isNotDistinctFrom
            } else {
                return op
            }
        case .isNotDistinctFrom:
            fatalError("guess will not return these since the look ahead is only 2")
        }
    }
}

extension Operator {
    var words: Int {
        return switch self {
        case .collate, .isNot, .not(.some), .notNull: 2
        case .isDistinctFrom: 3
        case .isNotDistinctFrom: 4
        default: 1
        }
    }
    
    /// Advances the parser past this operator
    func skip(state: inout ParserState) throws {
        for _ in 0..<words {
            try state.skip()
        }
    }
    
    static func precedence(
        for kind: Token.Kind,
        after: Token.Kind,
        usage: Operator.Usage
    ) -> Operator.Precedence? {
        return guess(for: kind, after: after)?.precedence(usage: usage)
    }
    
    static func guess(
        for kind: Token.Kind,
        after: Token.Kind
    ) -> Operator? {
        switch kind {
        case .tilde: return .tilde
        case .plus: return .plus
        case .minus: return .minus
        case .concat: return .concat
        case .arrow: return .arrow
        case .doubleArrow: return .doubleArrow
        case .star: return .multiply
        case .divide: return .divide
        case .cast: return .cast
        case .ampersand: return .bitwiseAnd
        case .pipe: return .bitwuseOr
        case .shiftLeft: return .shl
        case .shiftRight: return .shr
        case .escape: return .escape
        case .lt: return .lt
        case .gt: return .gt
        case .lte: return .lte
        case .gte: return .gte
        case .equal: return .eq
        case .doubleEqual: return .eq2
        case .notEqual: return .neq
        case .notEqual2: return .neq2
        case .and: return .and
        case .`in`: return .`in`
        case .match: return .match
        case .like: return .like
        case .regexp: return .regexp
        case .glob: return .glob
        case .isnull: return .isnull
        case .is:
            if after == .null {
                return .notNull
            } else if after == .distinct {
                return .isDistinctFrom
            } else if after == .not {
                return .isNot
            } else {
                return .is
            }
        case .notnull: return .notnull
        case .or: return .or
        case .between: return .between
        case .modulo: return .cast
        case .collate:
            guard case let .symbol(collation) = after else {
                return nil
            }
            return .collate(collation)
        case .not:
            if after == .null {
                return .notNull
            } else if after == .between {
                return .not(.between)
            } else if after == .in {
                return .not(.in)
            } else if after == .match {
                return .not(.match)
            } else if after == .like {
                return .not(.like)
            } else if after == .regexp {
                return .not(.regexp)
            } else if after == .glob {
                return .not(.glob)
            } else {
                return nil
            }
        default: return nil
        }
    }
}

extension Operator: Parsable {
    static let parser = OperatorParser()
}

/// https://www.sqlite.org/c3ref/bind_blob.html
struct BindParameterParser: Parser {
    func parse(state: inout ParserState) throws -> BindParameter? {
        switch state.current.kind {
        case .questionMark:
            try state.skip()
            if case let .symbol(param) = state.current.kind {
                try state.skip()
                return .named(String(param))
            } else {
                return .unnamed
            }
        case .colon:
            try state.skip()
            return try .named(String(parseSymbol(state: &state)))
        case .at:
            try state.skip()
            return try .named(String(parseSymbol(state: &state)))
        case .dollarSign:
            try state.skip()
            
            let symbol = try SymbolParser()
                .separated(by: .colon, and: .colon)
                .parse(state: &state)
                .joined(separator: "::")
            
            let suffix = try SymbolParser()
                .inParenthesis()
                .take(if: .openParen)
                .parse(state: &state)
            
            if let suffix {
                return .named("\(symbol)(\(suffix))")
            } else {
                return .named(symbol)
            }
        default:
            return nil
        }
    }
    
    private func parseSymbol(state: inout ParserState) throws -> Substring {
        return try SymbolParser()
            .parse(state: &state)
    }
}

extension BindParameter: Parsable {
    static let parser = BindParameterParser()
}

struct QualifiedColumnParser: Parser {
    func parse(state: inout ParserState) throws -> (
        schema: Substring?,
        table: Substring?,
        column: Substring
    )? {
        let symbol = SymbolParser()
        
        guard case let .symbol(first) = state.current.kind else {
            return nil
        }
        
        try state.skip()
        
        if try state.take(if: .dot) {
            let second = try symbol.parse(state: &state)
            
            if try state.take(if: .dot) {
                return (first, second, try symbol.parse(state: &state))
            } else {
                return (nil, first, second)
            }
        } else {
            return (nil, nil, first)
        }
    }
}
