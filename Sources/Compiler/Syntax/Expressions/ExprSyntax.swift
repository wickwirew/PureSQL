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
    mutating func visit(_ expr: borrowing ExistsExprSyntax) -> ExprOutput
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
        case let .exists(expr):
            return expr.accept(visitor: &self)
        case let .invalid(expr):
            return expr.accept(visitor: &self)
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
    case exists(ExistsExprSyntax)
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
        case let .exists(expr): expr.id
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
        case let .exists(expr): expr.location
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
        case let .exists(expr):
            return "\(expr)"
        case let .invalid(expr):
            return expr.description
        }
    }
}
