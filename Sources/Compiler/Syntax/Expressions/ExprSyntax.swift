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
    
    mutating func visit(_ expr: LiteralExprSyntax) -> ExprOutput
    mutating func visit(_ expr: BindParameterSyntax) -> ExprOutput
    mutating func visit(_ expr: ColumnExprSyntax) -> ExprOutput
    mutating func visit(_ expr: PrefixExprSyntax) -> ExprOutput
    mutating func visit(_ expr: InfixExprSyntax) -> ExprOutput
    mutating func visit(_ expr: PostfixExprSyntax) -> ExprOutput
    mutating func visit(_ expr: BetweenExprSyntax) -> ExprOutput
    mutating func visit(_ expr: FunctionExprSyntax) -> ExprOutput
    mutating func visit(_ expr: CastExprSyntax) -> ExprOutput
    mutating func visit(_ expr: CaseWhenThenExprSyntax) -> ExprOutput
    mutating func visit(_ expr: GroupedExprSyntax) -> ExprOutput
    mutating func visit(_ expr: SelectExprSyntax) -> ExprOutput
    mutating func visit(_ expr: ExistsExprSyntax) -> ExprOutput
    mutating func visit(_ expr: InvalidExprSyntax) -> ExprOutput
}
