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
        var expr = try PrimaryExprParser(precedence: precedence)
            .parse(state: &state)
        
        while true {
            // If the lhs was a column refernce with no table/schema and we are
            // at an open paren treat as a function call.
            if state.is(of: .openParen), case let .column(.none, table, fn) = expr {
                let args = try ExprParser()
                    .commaSeparated()
                    .inParenthesis()
                    .parse(state: &state)
                
                return .fn(table: table, name: fn, args: args)
            }
            
            guard let op = Operator.guess(for: state.current.kind, after: state.peek.kind),
                  op.precedence(usage: .infix) >= precedence else {
                return expr
            }
            
            // The between operator is a different one. It doesnt act like a
            // normal infix expression. There are two rhs expressions for the
            // lower and upper bounds. Those need to be parsed individually
            //
            // TODO: Move this to the Infix Parser
            if op == .between || op == .not(.between) {
                let op = try Operator.parse(state: &state)
                assert(op == .between || op == .not(.between), "Guess cannot be wrong")
                
                // We need to dispatch the lower and upper bound expr's with a
                // precedence above AND so the AND is not included in the expr.
                // e.g. (a BETWEEN b AND C) not (a BETWEEN (b AND c))
                let precAboveAnd = Operator.and.precedence(usage: .infix) + 1
                
                let lowerBound = try ExprParser(precedence: precAboveAnd)
                    .parse(state: &state)
                
                try state.take(.and)
                
                let upperBound = try ExprParser(precedence: precAboveAnd)
                    .parse(state: &state)
                
                expr = .between(op == .not(.between), expr, lowerBound, upperBound)
            } else {
                expr = try InfixExprParser(lhs: expr)
                    .parse(state: &state)
            }
        }
        
        return expr
    }
}


/// https://www.sqlite.org/syntax/expr.html
struct PrimaryExprParser: Parser {
    let precedence: Operator.Precedence
    
    func parse(state: inout ParserState) throws -> Expression {
        switch state.current.kind {
        case .double, .string, .int, .hex, .currentDate, .currentTime, .currentTimestamp, .true, .false:
            return .literal(try .parse(state: &state))
        case .symbol:
            let column = try QualifiedColumnParser()
                .parse(state: &state)
            return .column(schema: column.schema, table: column.table, column: column.column)
        case .questionMark, .colon, .dollarSign, .at:
            return try .bindParameter(.parse(state: &state))
        case .plus:
            try state.skip()
            return try .prefix(.plus, ExprParser(precedence: precedence).parse(state: &state))
        case .tilde:
            try state.skip()
            return try .prefix(.tilde, ExprParser(precedence: precedence).parse(state: &state))
        case .minus:
            try state.skip()
            return try .prefix(.minus, ExprParser(precedence: precedence).parse(state: &state))
        case .null:
            try state.skip()
            return .literal(.null)
        case .openParen:
            return .grouped(
                try ExprParser()
                    .commaSeparated()
                    .inParenthesis()
                    .parse(state: &state)
            )
        case .cast:
            try state.skip()
            try state.take(.openParen)
            let expr = try ExprParser()
                .parse(state: &state)
            try state.take(.as)
            let type = try TyParser()
                .parse(state: &state)
            try state.take(.closeParen)
            return .cast(expr, type)
        case .select:
            fatalError("TODO: Not yet implemented")
        case .exists:
            fatalError("TODO: Do when select is done")
        case .case:
            try state.skip()
            let `case` = try ExprParser()
                .take(ifNot: .when)
                .parse(state: &state)
            
            let whenThen = try WhenThenParser()
                .collect(if: [.when])
                .parse(state: &state)
            
            let el: Expression? = if try state.take(if: .else) {
                try ExprParser()
                    .parse(state: &state)
            } else {
                nil
            }
            
            try state.take(.end)
            
            return .caseWhenThen(.init(case: `case`, whenThen: whenThen, else: el))
        default:
            throw ParsingError(description: "Expected Expression", sourceRange: state.range)
        }
    }
}

struct WhenThenParser: Parser {
    func parse(state: inout ParserState) throws -> CaseWhenThen.WhenThen {
        try state.take(.when)
        let when = try ExprParser()
            .parse(state: &state)
        try state.take(.then)
        let then = try ExprParser()
            .parse(state: &state)
        return CaseWhenThen.WhenThen(when: when, then: then)
    }
}

struct InfixExprParser: Parser {
    let lhs: Expression

    func parse(state: inout ParserState) throws -> Expression {
        let op = try Operator.parse(state: &state)
        
        switch op {
        case .isnull, .notnull, .notNull, .collate:
            return .postfix(lhs, op)
        default: break
        }
        
        let rhs = try ExprParser(precedence: op.precedence(usage: .infix) + 1)
            .parse(state: &state)
        
        return .infix(lhs, op, rhs)
    }
}

struct PrefixOperatorParser: Parser {
    func parse(state: inout ParserState) throws -> Operator? {
        nil
    }
}

struct OperatorParser: Parser {
    func parse(state: inout ParserState) throws -> Operator {
        guard let op = Operator.guess(
            for: state.current.kind,
            after: state.peek.kind
        ) else {
            throw ParsingError(description: "Invalid operator", sourceRange: state.range)
        }
        
        try op.skip(state: &state)
        
        switch op {
        case .tilde, .collate, .concat, .arrow, .doubleArrow, .multiply, .divide,
             .mod, .plus, .minus, .bitwiseAnd, .bitwuseOr, .shl, .shr, .escape,
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
    
    /// Gives a guess as to what the operator is. This seems weird, cause when
    /// would you ever need to guess. Well when checking the precedence of the
    /// next operator we need to get the next operator. We don't have infinite look
    /// ahead but we only need the first 2 to get an operator close enough in the
    /// same precedence group.
    ///
    /// Example:
    /// `IS NOT DISTINCT FROM` will return `IS NOT`, which is in the same precendence group.
    /// https://www.sqlite.org/lang_expr.html
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
        case .cast: return .mod
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
            if after == .distinct {
                return .isDistinctFrom
            } else if after == .not {
                return .isNot
            } else {
                return .is
            }
        case .notnull: return .notnull
        case .or: return .or
        case .between: return .between
        case .modulo: return .mod
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
    func parse(state: inout ParserState) throws -> BindParameter {
        let token = try state.take()
        
        switch token.kind {
        case .questionMark:
            if case let .symbol(param) = state.current.kind {
                try state.skip()
                return .named(String(param))
            } else {
                return .unnamed
            }
        case .colon:
            return try .named(String(parseSymbol(state: &state)))
        case .at:
            return try .named(String(parseSymbol(state: &state)))
        case .dollarSign:
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
            throw ParsingError(description: "Invalid bind parameter", sourceRange: token.range)
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
    ) {
        let symbol = SymbolParser()
        
        let first = try symbol.parse(state: &state)
        
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
