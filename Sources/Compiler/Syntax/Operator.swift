//
//  Operator.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/4/25.
//

/// https://www.sqlite.org/lang_expr.html
enum Operator: Equatable {
    case tilde
    case collate(Substring)
    case concat
    case arrow
    case doubleArrow
    case multiply
    case divide
    case mod
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
    case between
    case and
    case `in`
    case match
    case like
    case regexp
    case glob
    case isnull
    case notNull // NOT NULL
    case notnull // NOTNULL
    indirect case not(Operator?)
    case or
    
    typealias Precedence = Int
    
    enum Usage {
        case prefix
        case infix
        case postfix
    }
    
    var canBePrefix: Bool {
        return switch self {
        case .plus, .tilde, .minus: true
        default: false
        }
    }
    
    var canHaveNotPrefix: Bool {
        return self == .between
            || self == .in
            || self == .match
            || self == .like
            || self == .regexp
            || self == .glob
    }
    
    var words: Int {
        return switch self {
        case .collate, .isNot, .not(.some), .notNull: 2
        case .isDistinctFrom: 3
        case .isNotDistinctFrom: 4
        default: 1
        }
    }
    
    /// Advances the parser past this operator
    func skip(state: inout ParserState) {
        for _ in 0..<words {
            state.skip()
        }
    }
    
    static func precedence(
        for kind: Token.Kind,
        after: Token.Kind,
        usage: Operator.Usage
    ) -> Operator.Precedence? {
        return guess(for: kind, after: after)?.precedence(usage: usage)
    }
    
    /// Gets the precedence for the operator in the given usage. If the operator
    /// is not valid for the usage then `nil` is returned.
    ///
    /// https://www.sqlite.org/lang_expr.html
    func precedence(usage: Usage) -> Precedence {
        switch usage {
        case .prefix:
            return switch self {
            case .tilde, .plus, .minus: 12
            default: 0
            }
        case .infix:
            return switch self {
            case .concat, .arrow, .doubleArrow: 10
            case .multiply, .divide, .mod: 9
            case .plus, .minus: 8
            case .bitwiseAnd, .bitwuseOr, .shl, .shr: 7
            case .escape: 6
            case .lt, .gt, .lte, .gte: 5
            case .eq, .eq2, .neq, .neq2, .is, .isNot, .isDistinctFrom,
                 .isNotDistinctFrom, .between, .in, .match, .like,
                 .regexp, .glob, .isnull, .notNull, .notnull: 4
            case let .not(op): op?.precedence(usage: usage) ?? 3
            case .and: 2
            case .or: 1
            default: 0
            }
        case .postfix:
            return switch self {
            case .collate: 11
            default: 0
            }
        }
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
        case .in: return .in
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
            guard case let .identifier(collation) = after else {
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

extension Operator: CustomStringConvertible {
    var description: String {
        return switch self {
        case .tilde: "~"
        case let .collate(collation): "COLLATE \(collation)"
        case .concat: "||"
        case .arrow: "->"
        case .doubleArrow: "->>"
        case .multiply: "*"
        case .divide: "/"
        case .mod: "%"
        case .plus: "+"
        case .minus: "-"
        case .bitwiseAnd: "&"
        case .bitwuseOr: "|"
        case .shl: "<<"
        case .shr: ">>"
        case .escape: "ESCAPE"
        case .lt: "<"
        case .gt: ">"
        case .lte: "<="
        case .gte: ">="
        case .eq: "="
        case .eq2: "=="
        case .neq: "!="
        case .neq2: "<>"
        case .is: "IS"
        case .isNot: "IS NOT"
        case .isDistinctFrom: "IS DISTINCT FROM"
        case .isNotDistinctFrom: "IS NOT DISTINCT FROM"
        case .between: "BETWEEN"
        case .and: "AND"
        case .in: "IN"
        case .match: "MATCH"
        case .like: "LIKE"
        case .regexp: "REGEXP"
        case .glob: "GLOB"
        case .isnull: "ISNULL"
        case .notNull: "NOT NULL"
        case .notnull: "NOTNULL"
        case let .not(op): op.map { "NOT \($0)" } ?? "NOT"
        case .or: "OR"
        }
    }
}
