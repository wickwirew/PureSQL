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

struct OperatorSyntax: CustomStringConvertible, Syntax {
    let id: SyntaxId
    let `operator`: Operator
    let location: SourceLocation
    
    var description: String {
        return `operator`.description
    }
}

struct LiteralExprSyntax: ExprSyntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
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
    
    var location: SourceLocation {
        return switch self {
        case let .literal(expr): expr.location
        case let .bindParameter(expr): expr.location
        case let .column(expr): expr.location
        case let .prefix(expr): expr.location
        case let .infix(expr): expr.location
        case let .postfix(expr): expr.location
        case let .between(expr): expr.location
        case let .fn(expr): expr.location
        case let .cast(expr): expr.location
        case let .grouped(expr): expr.location
        case let .caseWhenThen(expr): expr.location
        case let .select(expr): expr.location
        case let .invalid(expr): expr.location
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
    let location: SourceLocation
    
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
    
    var location: SourceLocation {
        return `operator`.location.spanning(rhs.location)
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
    
    var location: SourceLocation {
        return lhs.location.spanning(`operator`.location)
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
    
    var location: SourceLocation {
        return lhs.location.spanning(rhs.location)
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
    
    var location: SourceLocation {
        return value.location.spanning(upper.location)
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
    let location: SourceLocation
    
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
    let location: SourceLocation
    
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
    let location: SourceLocation
    
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
    
    var location: SourceLocation {
        let first = schema ?? table ?? column
        return first.location.spanning(column.location)
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
    let location: SourceLocation
    
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
    
    var location: SourceLocation {
        return select.location
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct InvalidExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let location: SourceLocation
    
    var description: String {
        return "<<invalid>>"
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}
