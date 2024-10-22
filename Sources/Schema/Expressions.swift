//
//  Expressions.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

import Foundation

public protocol ExprVisitor {
    associatedtype Output
    
    mutating func visit(_ expr: LiteralExpr) throws -> Output
    mutating func visit(_ expr: BindParameter) throws -> Output
    mutating func visit(_ expr: ColumnExpr) throws -> Output
    mutating func visit(_ expr: PrefixExpr) throws -> Output
    mutating func visit(_ expr: InfixExpr) throws -> Output
    mutating func visit(_ expr: PostfixExpr) throws -> Output
    mutating func visit(_ expr: BetweenExpr) throws -> Output
    mutating func visit(_ expr: FunctionExpr) throws -> Output
    mutating func visit(_ expr: CastExpr) throws -> Output
    mutating func visit(_ expr: CaseWhenThenExpr) throws -> Output
    mutating func visit(_ expr: GroupedExpr) throws -> Output
}

extension ExprVisitor {
    mutating func visit(_ expr: Expression) throws -> Output {
        switch expr {
        case .literal(let expr):
            return try expr.accept(visitor: &self)
        case .bindParameter(let expr):
            return try expr.accept(visitor: &self)
        case .column(let expr):
            return try expr.accept(visitor: &self)
        case .prefix(let expr):
            return try expr.accept(visitor: &self)
        case .infix(let expr):
            return try expr.accept(visitor: &self)
        case .postfix(let expr):
            return try expr.accept(visitor: &self)
        case .between(let expr):
            return try expr.accept(visitor: &self)
        case .fn(let expr):
            return try expr.accept(visitor: &self)
        case .cast(let expr):
            return try expr.accept(visitor: &self)
        case .grouped(let expr):
            return try expr.accept(visitor: &self)
        case .caseWhenThen(let expr):
            return try expr.accept(visitor: &self)
        }
    }
}

public protocol Expr {
    func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output
}

public enum LiteralExpr: Expr, Equatable {
    case numeric(Numeric, isInt: Bool)
    case string(Substring)
    case blob(Substring)
    case null
    case `true`
    case `false`
    case currentTime
    case currentDate
    case currentTimestamp
    
    public func accept<V>(visitor: inout V) throws -> V.Output where V : ExprVisitor {
        try visitor.visit(self)
    }
}

extension LiteralExpr: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value[...])
    }
}

extension LiteralExpr: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .numeric(Numeric(value), isInt: true)
    }
}

extension LiteralExpr: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .numeric(value, isInt: false)
    }
}

extension LiteralExpr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .numeric(let numeric, _):
            return numeric.description
        case .string(let substring):
            return "'\(substring.description)'"
        case .blob(let substring):
            return substring.description
        case .null:
            return "NULL"
        case .true:
            return "TRUE"
        case .false:
            return "FALSE"
        case .currentTime:
            return "CURRENT_TIME"
        case .currentDate:
            return "CURRENT_DATE"
        case .currentTimestamp:
            return "CURRENT_TIMESTAMP"
        }
    }
}

public indirect enum Expression: Expr, Equatable {
    case literal(LiteralExpr)
    case bindParameter(BindParameter)
    case column(ColumnExpr)
    case prefix(PrefixExpr)
    case infix(InfixExpr)
    case postfix(PostfixExpr)
    case between(BetweenExpr)
    case fn(FunctionExpr)
    case cast(CastExpr)
    // These are expressions in parentheses.
    // These can mean multiple things. It can be used to
    // estabilish precedence in arithmetic operations, or
    // could even be a collection of values.
    //
    // Examples:
    // (1 + 2)
    // foo IN (1, 2)
    case grouped(GroupedExpr)
    case caseWhenThen(CaseWhenThenExpr)
    
    public func accept<V>(visitor: inout V) throws -> V.Output where V : ExprVisitor {
        return try visitor.visit(self)
    }
}

extension Expression: CustomStringConvertible {
    public var description: String {
        switch self {
        case .literal(let literal):
            return literal.description
        case .bindParameter(let bindParameter):
            return bindParameter.description
        case .column(let expr):
            return expr.description
        case .prefix(let expr):
            return expr.description
        case .infix(let expr):
            return expr.description
        case .postfix(let expr):
            return expr.description
        case .between(let expr):
            return expr.description
        case .fn(let expr):
            return expr.description
        case .cast(let expr):
            return expr.description
        case .grouped(let expr):
            return expr.description
        case .caseWhenThen(let expr):
            return expr.description
        }
    }
}

public struct GroupedExpr: Expr, Equatable, CustomStringConvertible {
    public let exprs: [Expression]
    
    public init(exprs: [Expression]) {
        self.exprs = exprs
    }
    
    public var description: String {
        return "(\(exprs.map(\.description).joined(separator: ", ")))"
    }
    
    public func accept<V>(visitor: inout V) throws -> V.Output where V : ExprVisitor {
        return try visitor.visit(self)
    }
}

public struct PrefixExpr: Expr, Equatable, CustomStringConvertible {
    public let `operator`: Operator
    public let rhs: Expression
    
    public init(`operator`: Operator, rhs: Expression) {
        self.operator = `operator`
        self.rhs = rhs
    }
    
    public var description: String {
        return "(\(`operator`)\(rhs))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct PostfixExpr: Expr, Equatable, CustomStringConvertible {
    public let lhs: Expression
    public let `operator`: Operator
    
    public init(lhs: Expression, `operator`: Operator) {
        self.lhs = lhs
        self.operator = `operator`
    }
    
    public var description: String {
        return "(\(lhs) \(`operator`))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct InfixExpr: Expr, Equatable, CustomStringConvertible {
    public let lhs: Expression
    public let `operator`: Operator
    public let rhs: Expression
    
    public init(lhs: Expression, `operator`: Operator, rhs: Expression) {
        self.lhs = lhs
        self.operator = `operator`
        self.rhs = rhs
    }
    
    public var description: String {
        return "(\(lhs) \(`operator`) \(rhs))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct BetweenExpr: Expr, Equatable, CustomStringConvertible {
    public let not: Bool
    public let value: Expression
    public let lower: Expression
    public let upper: Expression
    
    public init(
        not: Bool,
        value: Expression,
        lower: Expression,
        upper: Expression
    ) {
        self.not = not
        self.value = value
        self.lower = lower
        self.upper = upper
    }
    
    public var description: String {
        return "(\(value)\(not ? " NOT" : "") BETWEEN \(lower) AND \(upper))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct FunctionExpr: Expr, Equatable, CustomStringConvertible {
    public let table: Substring?
    public let name: Substring
    public let args: [Expression]
    
    public init(
        table: Substring?,
        name: Substring,
        args: [Expression]
    ) {
        self.table = table
        self.name = name
        self.args = args
    }
    
    public var description: String {
        return "\(table.map { "\($0)." } ?? "")\(name)(\(args.map(\.description).joined(separator: ", ")))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct CastExpr: Expr, Equatable, CustomStringConvertible {
    public let expr: Expression
    public let ty: TypeName
    
    public init(expr: Expression, ty: TypeName) {
        self.expr = expr
        self.ty = ty
    }
    
    public var description: String {
        return "CAST(\(expr) AS \(ty))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public enum BindParameter: Expr, Equatable {
    case named(String)
    case unnamed
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
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

public struct ColumnExpr: Expr, Equatable, CustomStringConvertible {
    public let schema: Substring?
    public let table: Substring?
    public let column: Substring
    
    public init(
        schema: Substring?,
        table: Substring?,
        column: Substring
    ) {
        self.schema = schema
        self.table = table
        self.column = column
    }
    
    public var description: String {
        return [schema, table, column]
            .compactMap { $0 }
            .joined(separator: ".")
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct CaseWhenThenExpr: Expr, Equatable {
    public let `case`: Expression?
    public let whenThen: [WhenThen]
    public let `else`: Expression?
    
    public init(
        `case`: Expression?,
        whenThen: [WhenThen],
        `else`: Expression?
    ) {
        self.`case` = `case`
        self.whenThen = whenThen
        self.`else` = `else`
    }
    
    public struct WhenThen: Equatable {
        let when: Expression
        let then: Expression
        
        public init(when: Expression, then: Expression) {
            self.when = when
            self.then = then
        }
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

extension CaseWhenThenExpr: CustomStringConvertible {
    public var description: String {
        var str = "CASE"
        if let `case` = `case` {
            str += " \(`case`)"
        }
        for whenThen in whenThen {
            str += " WHEN \(whenThen.when) THEN \(whenThen.then)"
        }
        if let `else` = `else` {
            str += " ELSE \(`else`)"
        }
        str += " END"
        return str
    }
}
