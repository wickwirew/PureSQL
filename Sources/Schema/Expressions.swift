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
    mutating func visit(_ expr: SelectExpr) throws -> Output
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
        case .select(let expr):
            return try expr.accept(visitor: &self)
        }
    }
}

public struct OperatorSyntax: Equatable, CustomStringConvertible {
    public let `operator`: Operator
    public let range: Range<String.Index>
    
    public init(
        `operator`: Operator,
        range: Range<String.Index>
    ) {
        self.operator = `operator`
        self.range = range
    }
    
    public var description: String {
        return `operator`.description
    }
}

public protocol Expr {
    var range: Range<String.Index> { get }
    func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output
}

public struct LiteralExpr: Expr, Equatable {
    public let kind: Kind
    public let range: Range<String.Index>
    
    public enum Kind: Equatable {
        case numeric(Numeric, isInt: Bool)
        case string(Substring)
        case blob(Substring)
        case null
        case `true`
        case `false`
        case currentTime
        case currentDate
        case currentTimestamp
    }
    
    public init(kind: Kind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
    
    public func accept<V>(visitor: inout V) throws -> V.Output where V : ExprVisitor {
        try visitor.visit(self)
    }
}

extension LiteralExpr: CustomStringConvertible {
    public var description: String {
        switch self.kind {
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
    case select(SelectExpr)
    
    public var range: Range<String.Index> {
        return switch self {
        case .literal(let expr): expr.range
        case .bindParameter(let expr): expr.range
        case .column(let expr): expr.range
        case .prefix(let expr): expr.range
        case .infix(let expr): expr.range
        case .postfix(let expr): expr.range
        case .between(let expr): expr.range
        case .fn(let expr): expr.range
        case .cast(let expr): expr.range
        case .grouped(let expr): expr.range
        case .caseWhenThen(let expr): expr.range
        case .select(let expr): expr.range
        }
    }
    
    public var literal: LiteralExpr? {
        if case .literal(let l) = self { return l }
        return nil
    }
    
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
        case .select(let expr):
            return "\(expr)"
        }
    }
}

public struct GroupedExpr: Expr, Equatable, CustomStringConvertible {
    public let exprs: [Expression]
    public let range: Range<String.Index>
    
    public init(exprs: [Expression], range: Range<String.Index>) {
        self.exprs = exprs
        self.range = range
    }
    
    public var description: String {
        return "(\(exprs.map(\.description).joined(separator: ", ")))"
    }
    
    public func accept<V>(visitor: inout V) throws -> V.Output where V : ExprVisitor {
        return try visitor.visit(self)
    }
}

public struct PrefixExpr: Expr, Equatable, CustomStringConvertible {
    public let `operator`: OperatorSyntax
    public let rhs: Expression
    
    public init(`operator`: OperatorSyntax, rhs: Expression) {
        self.operator = `operator`
        self.rhs = rhs
    }
    
    public var description: String {
        return "(\(`operator`)\(rhs))"
    }
    
    public var range: Range<String.Index> {
        return `operator`.range.lowerBound..<rhs.range.upperBound
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct PostfixExpr: Expr, Equatable, CustomStringConvertible {
    public let lhs: Expression
    public let `operator`: OperatorSyntax
    
    public init(lhs: Expression, `operator`: OperatorSyntax) {
        self.lhs = lhs
        self.operator = `operator`
    }
    
    public var description: String {
        return "(\(lhs) \(`operator`))"
    }
    
    public var range: Range<String.Index> {
        return lhs.range.lowerBound..<`operator`.range.upperBound
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct InfixExpr: Expr, Equatable, CustomStringConvertible {
    public let lhs: Expression
    public let `operator`: OperatorSyntax
    public let rhs: Expression
    
    public var range: Range<String.Index> {
        return lhs.range.lowerBound..<rhs.range.upperBound
    }
    
    public init(lhs: Expression, `operator`: OperatorSyntax, rhs: Expression) {
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
    
    public var range: Range<String.Index> {
        return value.range.lowerBound..<upper.range.upperBound
    }
    
    public var description: String {
        return "(\(value)\(not ? " NOT" : "") BETWEEN \(lower) AND \(upper))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct FunctionExpr: Expr, Equatable, CustomStringConvertible {
    public let table: IdentifierSyntax?
    public let name: IdentifierSyntax
    public let args: [Expression]
    public let range: Range<String.Index>
    
    public init(
        table: IdentifierSyntax?,
        name: IdentifierSyntax,
        args: [Expression],
        range: Range<String.Index>
    ) {
        self.table = table
        self.name = name
        self.args = args
        self.range = range
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
    public let range: Range<String.Index>
    
    public init(expr: Expression, ty: TypeName, range: Range<String.Index>) {
        self.expr = expr
        self.ty = ty
        self.range = range
    }
    
    public var description: String {
        return "CAST(\(expr) AS \(ty))"
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct BindParameter: Expr, Hashable {
    public let kind: Kind
    public let range: Range<String.Index>
    
    public init(kind: Kind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
    
    public enum Kind: Hashable {
        case named(IdentifierSyntax)
        case unnamed(Int)
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

extension BindParameter: CustomStringConvertible {
    public var description: String {
        return switch kind {
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
    
    public var canBePrefix: Bool {
        return switch self {
        case .plus, .tilde, .minus: true
        default: false
        }
    }
    
    public var canHaveNotPrefix: Bool {
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
    public let schema: IdentifierSyntax?
    public let table: IdentifierSyntax?
    public let column: IdentifierSyntax // TODO: Support *
    
    public init(
        schema: IdentifierSyntax?,
        table: IdentifierSyntax?,
        column: IdentifierSyntax
    ) {
        self.schema = schema
        self.table = table
        self.column = column
    }
    
    public var description: String {
        return [schema, table, column]
            .compactMap { $0?.value }
            .joined(separator: ".")
    }
    
    public var range: Range<String.Index> {
        let first = schema ?? table ?? column
        return first.range.lowerBound..<column.range.upperBound
    }
    
    public func accept<V: ExprVisitor>(visitor: inout V) throws -> V.Output {
        try visitor.visit(self)
    }
}

public struct CaseWhenThenExpr: Expr, Equatable {
    public let `case`: Expression?
    public let whenThen: [WhenThen]
    public let `else`: Expression?
    public let range: Range<String.Index>
    
    public init(
        `case`: Expression?,
        whenThen: [WhenThen],
        `else`: Expression?,
        range: Range<String.Index>
    ) {
        self.`case` = `case`
        self.whenThen = whenThen
        self.`else` = `else`
        self.range = range
    }
    
    public struct WhenThen: Equatable {
        public let when: Expression
        public let then: Expression
        
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

public struct SelectExpr: Expr, Equatable {
    public let select: SelectStmt
    public let range: Range<String.Index>
    
    public init(select: SelectStmt, range: Range<String.Index>) {
        self.select = select
        self.range = range
    }
    
    public func accept<V>(visitor: inout V) throws -> V.Output where V : ExprVisitor {
        return try visitor.visit(self)
    }
}
