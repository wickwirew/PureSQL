//
//  ExprSyntax.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

protocol ExprSyntax: Syntax {
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput
}

protocol ExprSyntaxVisitor {
    associatedtype ExprOutput
    
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing CastExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> ExprOutput
    mutating func visit(_ expr: borrowing InvalidExprSyntax) -> ExprOutput
}

extension ExprSyntaxVisitor {
    mutating func visit(_ expr: ExpressionSyntax) -> ExprOutput {
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
    let id: SyntaxId
    let `operator`: Operator
    let range: SourceLocation
    
    var description: String {
        return `operator`.description
    }
}

struct LiteralExprSyntax: ExprSyntax {
    let id: SyntaxId
    let kind: Kind
    let range: SourceLocation
    
    enum Kind {
        case numeric(NumericSyntax, isInt: Bool)
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
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}

extension LiteralExprSyntax: CustomStringConvertible {
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

indirect enum ExpressionSyntax: ExprSyntax {
    case literal(LiteralExprSyntax)
    case bindParameter(BindParameterSyntax)
    case column(ColumnExprSyntax)
    case prefix(PrefixExprSyntax)
    case infix(InfixExprSyntax)
    case postfix(PostfixExprSyntax)
    case between(BetweenExprSyntax)
    case fn(FunctionExprSyntax)
    case cast(CastExprSyntax)
    // These are expressions in parentheses.
    // These can mean multiple things. It can be used to
    // estabilish precedence in arithmetic operations, or
    // could even be a collection of values.
    //
    // Examples:
    // (1 + 2)
    // foo IN (1, 2)
    case grouped(GroupedExprSyntax)
    case caseWhenThen(CaseWhenThenExprSyntax)
    case select(SelectExprSyntax)
    case invalid(InvalidExprSyntax)
    
    var id: SyntaxId {
        return switch self {
        case let .literal(expr): expr.id
        case let .bindParameter(expr): expr.id
        case let .column(expr): expr.id
        case let .prefix(expr): expr.id
        case let .infix(expr): expr.id
        case let .postfix(expr): expr.id
        case let .between(expr): expr.id
        case let .fn(expr): expr.id
        case let .cast(expr): expr.id
        case let .grouped(expr): expr.id
        case let .caseWhenThen(expr): expr.id
        case let .select(expr): expr.id
        case let .invalid(expr): expr.id
        }
    }
    
    var range: SourceLocation {
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
    
    var literal: LiteralExprSyntax? {
        if case let .literal(l) = self { return l }
        return nil
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}

extension ExpressionSyntax: CustomStringConvertible {
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

struct GroupedExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let exprs: [ExpressionSyntax]
    let range: SourceLocation
    
    var description: String {
        return "(\(exprs.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct PrefixExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let `operator`: OperatorSyntax
    let rhs: ExpressionSyntax
    
    var description: String {
        return "(\(`operator`)\(rhs))"
    }
    
    var range: SourceLocation {
        return `operator`.range.spanning(rhs.range)
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct PostfixExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let lhs: ExpressionSyntax
    let `operator`: OperatorSyntax
    
    var description: String {
        return "(\(lhs) \(`operator`))"
    }
    
    var range: SourceLocation {
        return lhs.range.spanning(`operator`.range)
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct InfixExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let lhs: ExpressionSyntax
    let `operator`: OperatorSyntax
    let rhs: ExpressionSyntax
    
    var range: SourceLocation {
        return lhs.range.spanning(rhs.range)
    }
    
    var description: String {
        return "(\(lhs) \(`operator`) \(rhs))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct BetweenExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let not: Bool
    let value: ExpressionSyntax
    let lower: ExpressionSyntax
    let upper: ExpressionSyntax
    
    var range: SourceLocation {
        return value.range.spanning(upper.range)
    }
    
    var description: String {
        return "(\(value)\(not ? " NOT" : "") BETWEEN \(lower) AND \(upper))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct FunctionExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let table: IdentifierSyntax?
    let name: IdentifierSyntax
    let args: [ExpressionSyntax]
    let range: SourceLocation
    
    var description: String {
        return "\(table.map { "\($0)." } ?? "")\(name)(\(args.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct CastExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let expr: ExpressionSyntax
    let ty: TypeNameSyntax
    let range: SourceLocation
    
    var description: String {
        return "CAST(\(expr) AS \(ty))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct BindParameterSyntax: ExprSyntax, Hashable, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let index: Index
    let range: SourceLocation
    
    typealias Index = Int
    
    enum Kind: Hashable {
        case named(IdentifierSyntax)
        case unnamed
    }
    
    var description: String {
        return switch kind {
        case let .named(name): name.description
        case .unnamed: "?"
        }
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
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

struct ColumnExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let schema: IdentifierSyntax?
    let table: IdentifierSyntax?
    let column: IdentifierSyntax // TODO: Support *
    
    var description: String {
        return [schema, table, column]
            .compactMap { $0?.value }
            .joined(separator: ".")
    }
    
    var range: SourceLocation {
        let first = schema ?? table ?? column
        return first.range.spanning(column.range)
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

struct CaseWhenThenExprSyntax: ExprSyntax {
    let id: SyntaxId
    let `case`: ExpressionSyntax?
    let whenThen: [WhenThen]
    let `else`: ExpressionSyntax?
    let range: SourceLocation
    
    struct WhenThen {
        let when: ExpressionSyntax
        let then: ExpressionSyntax
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

extension CaseWhenThenExprSyntax: CustomStringConvertible {
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

struct SelectExprSyntax: ExprSyntax {
    let id: SyntaxId
    let select: SelectStmtSyntax
    
    var range: SourceLocation {
        return select.range
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct InvalidExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let range: SourceLocation
    
    var description: String {
        return "<<invalid>>"
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}
