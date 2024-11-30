//
//  ExprParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//



/// https://www.sqlite.org/syntax/expr.html
struct PrimaryExprParser: Parser {
    let precedence: Operator.Precedence
    
    func parse(state: inout ParserState) throws -> Expression {
        switch state.current.kind {
        case .double, .string, .int, .hex, .currentDate, .currentTime, .currentTimestamp, .true, .false:
            return .literal(try Parsers.literal(state: &state))
        case .symbol:
            let column = try Parsers.columnExpr(state: &state)
            return .column(column)
        case .questionMark, .colon, .dollarSign, .at:
            return try .bindParameter(Parsers.bindParameter(state: &state))
        case .plus:
            let token = try state.take()
            let op = OperatorSyntax(operator: .plus, range: token.range)
            return try .prefix(PrefixExpr(operator: op, rhs: Parsers.expr(state: &state, precedence: precedence)))
        case .tilde:
            let token = try state.take()
            let op = OperatorSyntax(operator: .tilde, range: token.range)
            return try .prefix(PrefixExpr(operator: op, rhs: Parsers.expr(state: &state, precedence: precedence)))
        case .minus:
            let token = try state.take()
            let op = OperatorSyntax(operator: .minus, range: token.range)
            return try .prefix(PrefixExpr(operator: op, rhs: Parsers.expr(state: &state, precedence: precedence)))
        case .null:
            let token = try state.take()
            return .literal(LiteralExpr(kind: .null, range: token.range))
        case .openParen:
            let start = state.current.range
            let expr = try Parsers.parens(state: &state) { state in
                try Parsers.commaDelimited(state: &state) { try Parsers.expr(state: &$0) }
            }
            return .grouped(GroupedExpr(exprs: expr, range: state.range(from: start)))
        case .cast:
            let start = try state.take()
            try state.consume(.openParen)
            let expr = try Parsers.expr(state: &state)
            try state.consume(.as)
            let type = try Parsers.typeName(state: &state)
            try state.consume(.closeParen)
            return .cast(CastExpr(expr: expr, ty: type, range: state.range(from: start.range)))
        case .select:
            fatalError("TODO: Not yet implemented")
        case .exists:
            fatalError("TODO: Do when select is done")
        case .case:
            let start = try state.take()
            let `case` = try Parsers.take(ifNot: .when, state: &state) { try Parsers.expr(state: &$0) }
            
            let whenThen = try WhenThenParser()
                .collect(if: [.when])
                .parse(state: &state)
            
            let el: Expression? = if try state.take(if: .else) {
                try Parsers.expr(state: &state)
            } else {
                nil
            }
            
            try state.consume(.end)
            
            return .caseWhenThen(.init(case: `case`, whenThen: whenThen, else: el, range: state.range(from: start.range)))
        default:
            throw ParsingError(description: "Expected Expression", sourceRange: state.range)
        }
    }
}

struct WhenThenParser: Parser {
    func parse(state: inout ParserState) throws -> CaseWhenThenExpr.WhenThen {
        try state.consume(.when)
        let when = try Parsers.expr(state: &state)
        try state.consume(.then)
        let then = try Parsers.expr(state: &state)
        return CaseWhenThenExpr.WhenThen(when: when, then: then)
    }
}

struct InfixExprParser: Parser {
    let lhs: Expression

    func parse(state: inout ParserState) throws -> Expression {
        let op = try Parsers.operator(state: &state)
        
        switch op.operator {
        case .isnull, .notnull, .notNull, .collate:
            return .postfix(PostfixExpr(lhs: lhs, operator: op))
        default: break
        }
        
        let rhs = try Parsers.expr(
            state: &state,
            precedence: op.operator.precedence(usage: .infix) + 1
        )
        
        return .infix(InfixExpr(lhs: lhs, operator: op, rhs: rhs))
    }
}

struct PrefixOperatorParser: Parser {
    func parse(state: inout ParserState) throws -> Operator? {
        nil
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
