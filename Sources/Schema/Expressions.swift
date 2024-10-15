//
//  Expressions.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

import Foundation

public indirect enum Expression: Equatable {
    case literal(Literal)
    case bindParameter(BindParameter)
    case column(schema: Substring?, table: Substring?, column: Substring)
    case prefix(Operator, Expression)
    case infix(Expression, Operator, Expression)
    case postfix(Expression, Operator)
    case between(Bool, Expression, Expression, Expression)
}

extension Expression: CustomStringConvertible {
    public var description: String {
        switch self {
        case .literal(let literal):
            return literal.description
        case .bindParameter(let bindParameter):
            return bindParameter.description
        case .column(let schema, let table, let column):
            return [schema, table, column]
                .compactMap { $0 }
                .joined(separator: ".")
        case .prefix(let `operator`, let expression):
            return "(\(`operator`)\(expression))"
        case .infix(let expression, let `operator`, let expression2):
            return "(\(expression) \(`operator`) \(expression2))"
        case .postfix(let expression, let `operator`):
            return "(\(expression) \(`operator`))"
        case let .between(not, value, lower, upper):
            return "(\(value)\(not ? " NOT" : "") BETWEEN \(lower) AND \(upper))"
        }
    }
}

public enum BindParameter: Equatable {
    case named(String)
    case unnamed
}

extension BindParameter: CustomStringConvertible {
    public var description: String {
        return switch self {
        case .named(let name): ":\(name)"
        case .unnamed: "?"
        }
    }
}

public enum Operator: Equatable {
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
    
    public typealias Precedence = Int
    
    public enum Usage {
        case prefix
        case infix
        case postfix
    }
    
    var canHaveNotPrefix: Bool {
        return self == .between
            || self == .in
            || self == .match
            || self == .like
            || self == .regexp
            || self == .glob
    }
    
    /// Gets the precedence for the operator in the given usage. If the operator
    /// is not valid for the usage then `nil` is returned.
    ///
    /// https://www.sqlite.org/lang_expr.html
    public func precedence(usage: Usage) -> Precedence {
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
            case .not(let op): op?.precedence(usage: usage) ?? 3
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
}

extension Operator: CustomStringConvertible {
    public var description: String {
        return switch self {
        case .tilde: "~"
        case .collate(let collation): "COLLATE \(collation)"
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
        case .`is`: "IS"
        case .isNot: "IS NOT"
        case .isDistinctFrom: "IS DISTINCT FROM"
        case .isNotDistinctFrom: "IS NOT DISTINCT FROM"
        case .between: "BETWEEN"
        case .and: "AND"
        case .`in`: "IN"
        case .match: "MATCH"
        case .like: "LIKE"
        case .regexp: "REGEXP"
        case .glob: "GLOB"
        case .isnull: "ISNULL"
        case .notNull: "NOT NULL"
        case .notnull: "NOTNULL"
        case .not(let op): op.map { "NOT \($0)" } ?? "NOT"
        case .or: "OR"
        }
    }
}
