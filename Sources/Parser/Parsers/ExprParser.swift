//
//  ExprParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// https://www.sqlite.org/syntax/expr.html
struct ExprParser: Parser {
    func parse(state: inout ParserState) throws -> Expr {
        // TODO
        return Expr() // .literal(.null)
    }
}

/// https://www.sqlite.org/c3ref/bind_blob.html
struct BindParameterParser: Parser {
    func parse(state: inout ParserState) throws -> BindParameter {
        let token = try state.take()
        
        switch token.kind {
        case .questionMark:
            if case let .symbol(param) = state.current.kind {
                try state.skip()
                return .named(param)
            } else {
                return .unnamed
            }
        case .colon:
            return try .named(SymbolParser().parse(state: &state))
        case .ampersand:
            return try .named(SymbolParser().parse(state: &state))
        case .dollarSign:
            return try .named(SymbolParser().parse(state: &state))
        default:
            throw ParsingError.expected(.questionMark, .colon, .ampersand, .dollarSign, at: token.range)
        }
    }
}

public enum BindParameter {
    case named(Substring)
    case unnamed
}

public enum Operator: Equatable {
    case tildeUnary
    case plusUnary
    case minusUnary
    case collate(Substring)
    case concat
    case arrow
    case doubleArrow
    case multiply
    case divide
    case cast
    case plus
    case minus
    case bitwiseAnd
    case bitwuseOr
    case shl
    case shr
    case escape
    case lt
    case gt
    case lte
    case gte
    case eq
    case eq2
    case neq
    case neq2
    case `is`
    case isNot
    case isDistinctFrom
    case isNotDistinctFrom
    case betweenAnd
    case and
    case `in`
    case match
    case like
    case regexp
    case glob
    case isNull
    case notNull
    case notNull2
    indirect case not(Operator?)
    case or
    
    typealias Precedence = Int
    
    var canHaveNotPrefix: Bool {
        return self == .betweenAnd
            || self == .in
            || self == .match
            || self == .like
            || self == .regexp
            || self == .glob
    }
    
    var precedence: Precedence {
        return switch self {
        case .tildeUnary, .plusUnary, .minusUnary: 12
        case .collate: 11
        case .concat, .arrow, .doubleArrow: 10
        case .multiply, .divide, .cast: 9
        case .plus, .minus: 8
        case .bitwiseAnd, .bitwuseOr, .shl, .shr: 7
        case .escape: 6
        case .lt, .gt, .lte, .gte: 5
        case .eq, .eq2, .neq, .neq2, .is, .isNot, .isDistinctFrom,
                .isNotDistinctFrom, .betweenAnd, .in, .match, .like,
                .regexp, .glob, .isNull, .notNull, .notNull2: 4
        case .not(let op): op?.precedence ?? 3
        case .and: 2
        case .or: 1
        }
    }
}
