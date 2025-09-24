//
//  FunctionExprSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct FunctionExprSyntax: ExprSyntax {
    let id: SyntaxId
    let table: IdentifierSyntax?
    let name: IdentifierSyntax
    let args: [any ExprSyntax]
    let location: SourceLocation

    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
