//
//  Expressions.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

import Foundation

protocol ExprVisitor {
    associatedtype Output
    
    mutating func visit(_ expr: borrowing LiteralExpr) -> Output
    mutating func visit(_ expr: borrowing BindParameter) -> Output
    mutating func visit(_ expr: borrowing ColumnExpr) -> Output
    mutating func visit(_ expr: borrowing PrefixExpr) -> Output
    mutating func visit(_ expr: borrowing InfixExpr) -> Output
    mutating func visit(_ expr: borrowing PostfixExpr) -> Output
    mutating func visit(_ expr: borrowing BetweenExpr) -> Output
    mutating func visit(_ expr: borrowing FunctionExpr) -> Output
    mutating func visit(_ expr: borrowing CastExpr) -> Output
    mutating func visit(_ expr: borrowing CaseWhenThenExpr) -> Output
    mutating func visit(_ expr: borrowing GroupedExpr) -> Output
    mutating func visit(_ expr: borrowing SelectExpr) -> Output
}

extension ExprVisitor {
    mutating func visit(_ expr: Expression) -> Output {
        switch expr {
        case .literal(let expr):
            return expr.accept(visitor: &self)
        case .bindParameter(let expr):
            return expr.accept(visitor: &self)
        case .column(let expr):
            return expr.accept(visitor: &self)
        case .prefix(let expr):
            return expr.accept(visitor: &self)
        case .infix(let expr):
            return expr.accept(visitor: &self)
        case .postfix(let expr):
            return expr.accept(visitor: &self)
        case .between(let expr):
            return expr.accept(visitor: &self)
        case .fn(let expr):
            return expr.accept(visitor: &self)
        case .cast(let expr):
            return expr.accept(visitor: &self)
        case .grouped(let expr):
            return expr.accept(visitor: &self)
        case .caseWhenThen(let expr):
            return expr.accept(visitor: &self)
        case .select(let expr):
            return expr.accept(visitor: &self)
        }
    }
}

struct OperatorSyntax: Equatable, CustomStringConvertible {
    let `operator`: Operator
    let range: Range<String.Index>
    
    init(
        `operator`: Operator,
        range: Range<String.Index>
    ) {
        self.operator = `operator`
        self.range = range
    }
    
    var description: String {
        return `operator`.description
    }
}

protocol Expr {
    var range: Range<String.Index> { get }
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output
}

struct LiteralExpr: Expr, Equatable {
    let kind: Kind
    let range: Range<String.Index>
    
    enum Kind: Equatable {
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
    
    init(kind: Kind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : ExprVisitor {
        return visitor.visit(self)
    }
}

extension LiteralExpr: CustomStringConvertible {
    var description: String {
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

indirect enum Expression: Expr, Equatable {
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
    
    var range: Range<String.Index> {
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
    
    var literal: LiteralExpr? {
        if case .literal(let l) = self { return l }
        return nil
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : ExprVisitor {
        return visitor.visit(self)
    }
}

extension Expression: CustomStringConvertible {
    var description: String {
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

struct GroupedExpr: Expr, Equatable, CustomStringConvertible {
    let exprs: [Expression]
    let range: Range<String.Index>
    
    init(exprs: [Expression], range: Range<String.Index>) {
        self.exprs = exprs
        self.range = range
    }
    
    var description: String {
        return "(\(exprs.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : ExprVisitor {
        return visitor.visit(self)
    }
}

struct PrefixExpr: Expr, Equatable, CustomStringConvertible {
    let `operator`: OperatorSyntax
    let rhs: Expression
    
    init(`operator`: OperatorSyntax, rhs: Expression) {
        self.operator = `operator`
        self.rhs = rhs
    }
    
    var description: String {
        return "(\(`operator`)\(rhs))"
    }
    
    var range: Range<String.Index> {
        return `operator`.range.lowerBound..<rhs.range.upperBound
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct PostfixExpr: Expr, Equatable, CustomStringConvertible {
    let lhs: Expression
    let `operator`: OperatorSyntax
    
    init(lhs: Expression, `operator`: OperatorSyntax) {
        self.lhs = lhs
        self.operator = `operator`
    }
    
    var description: String {
        return "(\(lhs) \(`operator`))"
    }
    
    var range: Range<String.Index> {
        return lhs.range.lowerBound..<`operator`.range.upperBound
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct InfixExpr: Expr, Equatable, CustomStringConvertible {
    let lhs: Expression
    let `operator`: OperatorSyntax
    let rhs: Expression
    
    var range: Range<String.Index> {
        return lhs.range.lowerBound..<rhs.range.upperBound
    }
    
    init(lhs: Expression, `operator`: OperatorSyntax, rhs: Expression) {
        self.lhs = lhs
        self.operator = `operator`
        self.rhs = rhs
    }
    
    var description: String {
        return "(\(lhs) \(`operator`) \(rhs))"
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct BetweenExpr: Expr, Equatable, CustomStringConvertible {
    let not: Bool
    let value: Expression
    let lower: Expression
    let upper: Expression
    
    init(
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
    
    var range: Range<String.Index> {
        return value.range.lowerBound..<upper.range.upperBound
    }
    
    var description: String {
        return "(\(value)\(not ? " NOT" : "") BETWEEN \(lower) AND \(upper))"
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct FunctionExpr: Expr, Equatable, CustomStringConvertible {
    let table: IdentifierSyntax?
    let name: IdentifierSyntax
    let args: [Expression]
    let range: Range<String.Index>
    
    init(
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
    
    var description: String {
        return "\(table.map { "\($0)." } ?? "")\(name)(\(args.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct CastExpr: Expr, Equatable, CustomStringConvertible {
    let expr: Expression
    let ty: TypeName
    let range: Range<String.Index>
    
    init(expr: Expression, ty: TypeName, range: Range<String.Index>) {
        self.expr = expr
        self.ty = ty
        self.range = range
    }
    
    var description: String {
        return "CAST(\(expr) AS \(ty))"
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct BindParameter: Expr, Hashable {
    let kind: Kind
    let range: Range<String.Index>
    
    init(kind: Kind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
    
    enum Kind: Hashable {
        case named(IdentifierSyntax)
        case unnamed(Int)
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

extension BindParameter: CustomStringConvertible {
    var description: String {
        return switch kind {
        case .named(let name): ":\(name)"
        case .unnamed: "?"
        }
    }
}

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
    var description: String {
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

struct ColumnExpr: Expr, Equatable, CustomStringConvertible {
    let schema: IdentifierSyntax?
    let table: IdentifierSyntax?
    let column: IdentifierSyntax // TODO: Support *
    
    init(
        schema: IdentifierSyntax?,
        table: IdentifierSyntax?,
        column: IdentifierSyntax
    ) {
        self.schema = schema
        self.table = table
        self.column = column
    }
    
    var description: String {
        return [schema, table, column]
            .compactMap { $0?.value }
            .joined(separator: ".")
    }
    
    var range: Range<String.Index> {
        let first = schema ?? table ?? column
        return first.range.lowerBound..<column.range.upperBound
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

struct CaseWhenThenExpr: Expr, Equatable {
    let `case`: Expression?
    let whenThen: [WhenThen]
    let `else`: Expression?
    let range: Range<String.Index>
    
    init(
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
    
    struct WhenThen: Equatable {
        let when: Expression
        let then: Expression
        
        init(when: Expression, then: Expression) {
            self.when = when
            self.then = then
        }
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.Output {
        return visitor.visit(self)
    }
}

extension CaseWhenThenExpr: CustomStringConvertible {
    var description: String {
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

struct SelectExpr: Expr, Equatable {
    let select: SelectStmt
    let range: Range<String.Index>
    
    init(select: SelectStmt, range: Range<String.Index>) {
        self.select = select
        self.range = range
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : ExprVisitor {
        return visitor.visit(self)
    }
}
