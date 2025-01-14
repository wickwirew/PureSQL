//
//  Expressions.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

import Foundation

protocol ExprVisitor {
    associatedtype ExprOutput
    
    mutating func visit(_ expr: borrowing LiteralExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing BindParameter) -> ExprOutput
    mutating func visit(_ expr: borrowing ColumnExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing PrefixExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing InfixExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing PostfixExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing BetweenExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing FunctionExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing CastExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing CaseWhenThenExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing GroupedExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing SelectExpr) -> ExprOutput
    mutating func visit(_ expr: borrowing InvalidExpr) -> ExprOutput
}

extension ExprVisitor {
    mutating func visit(_ expr: Expression) -> ExprOutput {
        switch expr {
        case let .literal(expr):
            return expr.accept(visitor: &self)
        case let .bindParameter(expr):
            return expr.accept(visitor: &self)
        case let .column(expr):
            return expr.accept(visitor: &self)
        case let .prefix(expr):
            return expr.accept(visitor: &self)
        case let .infix(expr):
            return expr.accept(visitor: &self)
        case let .postfix(expr):
            return expr.accept(visitor: &self)
        case let .between(expr):
            return expr.accept(visitor: &self)
        case let .fn(expr):
            return expr.accept(visitor: &self)
        case let .cast(expr):
            return expr.accept(visitor: &self)
        case let .grouped(expr):
            return expr.accept(visitor: &self)
        case let .caseWhenThen(expr):
            return expr.accept(visitor: &self)
        case let .select(expr):
            return expr.accept(visitor: &self)
        case let .invalid(expr):
            return expr.accept(visitor: &self)
        }
    }
}

struct OperatorSyntax: CustomStringConvertible {
    let `operator`: Operator
    let range: Range<String.Index>
    
    init(
        operator: Operator,
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
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput
}

struct LiteralExpr: Expr {
    let kind: Kind
    let range: Range<String.Index>
    
    enum Kind {
        case numeric(Numeric, isInt: Bool)
        case string(Substring)
        case blob(Substring)
        case null
        case `true`
        case `false`
        case currentTime
        case currentDate
        case currentTimestamp
        case invalid
    }
    
    init(kind: Kind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprVisitor {
        return visitor.visit(self)
    }
}

extension LiteralExpr: CustomStringConvertible {
    var description: String {
        switch self.kind {
        case let .numeric(numeric, _):
            return numeric.description
        case let .string(substring):
            return "'\(substring.description)'"
        case let .blob(substring):
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
        case .invalid:
            return "<<invalid>>"
        }
    }
}

indirect enum Expression: Expr {
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
    case invalid(InvalidExpr)
    
    var range: Range<String.Index> {
        return switch self {
        case let .literal(expr): expr.range
        case let .bindParameter(expr): expr.range
        case let .column(expr): expr.range
        case let .prefix(expr): expr.range
        case let .infix(expr): expr.range
        case let .postfix(expr): expr.range
        case let .between(expr): expr.range
        case let .fn(expr): expr.range
        case let .cast(expr): expr.range
        case let .grouped(expr): expr.range
        case let .caseWhenThen(expr): expr.range
        case let .select(expr): expr.range
        case let .invalid(expr): expr.range
        }
    }
    
    var literal: LiteralExpr? {
        if case let .literal(l) = self { return l }
        return nil
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprVisitor {
        return visitor.visit(self)
    }
}

extension Expression: CustomStringConvertible {
    var description: String {
        switch self {
        case let .literal(literal):
            return literal.description
        case let .bindParameter(bindParameter):
            return bindParameter.description
        case let .column(expr):
            return expr.description
        case let .prefix(expr):
            return expr.description
        case let .infix(expr):
            return expr.description
        case let .postfix(expr):
            return expr.description
        case let .between(expr):
            return expr.description
        case let .fn(expr):
            return expr.description
        case let .cast(expr):
            return expr.description
        case let .grouped(expr):
            return expr.description
        case let .caseWhenThen(expr):
            return expr.description
        case let .select(expr):
            return "\(expr)"
        case let .invalid(expr):
            return expr.description
        }
    }
}

struct GroupedExpr: Expr, CustomStringConvertible {
    let exprs: [Expression]
    let range: Range<String.Index>
    
    init(exprs: [Expression], range: Range<String.Index>) {
        self.exprs = exprs
        self.range = range
    }
    
    var description: String {
        return "(\(exprs.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprVisitor {
        return visitor.visit(self)
    }
}

struct PrefixExpr: Expr, CustomStringConvertible {
    let `operator`: OperatorSyntax
    let rhs: Expression
    
    init(operator: OperatorSyntax, rhs: Expression) {
        self.operator = `operator`
        self.rhs = rhs
    }
    
    var description: String {
        return "(\(`operator`)\(rhs))"
    }
    
    var range: Range<String.Index> {
        return `operator`.range.lowerBound..<rhs.range.upperBound
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct PostfixExpr: Expr, CustomStringConvertible {
    let lhs: Expression
    let `operator`: OperatorSyntax
    
    init(lhs: Expression, operator: OperatorSyntax) {
        self.lhs = lhs
        self.operator = `operator`
    }
    
    var description: String {
        return "(\(lhs) \(`operator`))"
    }
    
    var range: Range<String.Index> {
        return lhs.range.lowerBound..<`operator`.range.upperBound
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct InfixExpr: Expr, CustomStringConvertible {
    let lhs: Expression
    let `operator`: OperatorSyntax
    let rhs: Expression
    
    var range: Range<String.Index> {
        return lhs.range.lowerBound..<rhs.range.upperBound
    }
    
    init(lhs: Expression, operator: OperatorSyntax, rhs: Expression) {
        self.lhs = lhs
        self.operator = `operator`
        self.rhs = rhs
    }
    
    var description: String {
        return "(\(lhs) \(`operator`) \(rhs))"
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct BetweenExpr: Expr, CustomStringConvertible {
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
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct FunctionExpr: Expr, CustomStringConvertible {
    let table: Identifier?
    let name: Identifier
    let args: [Expression]
    let range: Range<String.Index>
    
    init(
        table: Identifier?,
        name: Identifier,
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
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct CastExpr: Expr, CustomStringConvertible {
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
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct BindParameter: Expr, Hashable, CustomStringConvertible {
    let kind: Kind
    let index: Index
    let range: Range<String.Index>
    
    typealias Index = Int
    
    enum Kind: Hashable {
        case named(Identifier)
        case unnamed
    }
    
    var description: String {
        return switch kind {
        case let .named(name): name.description
        case .unnamed: "?"
        }
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
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

struct ColumnExpr: Expr, CustomStringConvertible {
    let schema: Identifier?
    let table: Identifier?
    let column: Identifier // TODO: Support *
    
    init(
        schema: Identifier?,
        table: Identifier?,
        column: Identifier
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
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct CaseWhenThenExpr: Expr {
    let `case`: Expression?
    let whenThen: [WhenThen]
    let `else`: Expression?
    let range: Range<String.Index>
    
    init(
        case: Expression?,
        whenThen: [WhenThen],
        else: Expression?,
        range: Range<String.Index>
    ) {
        self.case = `case`
        self.whenThen = whenThen
        self.else = `else`
        self.range = range
    }
    
    struct WhenThen {
        let when: Expression
        let then: Expression
        
        init(when: Expression, then: Expression) {
            self.when = when
            self.then = then
        }
    }
    
    func accept<V: ExprVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

extension CaseWhenThenExpr: CustomStringConvertible {
    var description: String {
        var str = "CASE"
        if let `case` {
            str += " \(`case`)"
        }
        for whenThen in whenThen {
            str += " WHEN \(whenThen.when) THEN \(whenThen.then)"
        }
        if let `else` {
            str += " ELSE \(`else`)"
        }
        str += " END"
        return str
    }
}

struct SelectExpr: Expr {
    let select: SelectStmt
    let range: Range<String.Index>
    
    init(select: SelectStmt, range: Range<String.Index>) {
        self.select = select
        self.range = range
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprVisitor {
        return visitor.visit(self)
    }
}

struct InvalidExpr: Expr, CustomStringConvertible {
    let range: Range<String.Index>
    
    var description: String {
        return "<<invalid>>"
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprVisitor {
        return visitor.visit(self)
    }
}
