//
//  PostfixExprSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/lang_expr.html
struct PostfixExprSyntax: ExprSyntax {
    let id: SyntaxId
    let lhs: any ExprSyntax
    let `operator`: OperatorSyntax

    var location: SourceLocation {
        return lhs.location.spanning(`operator`.location)
    }

    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
