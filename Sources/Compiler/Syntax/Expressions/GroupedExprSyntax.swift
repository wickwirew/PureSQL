//
//  GroupedExprSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

/// A single or many expressions in parenthesis
/// 
/// https://www.sqlite.org/lang_expr.html
struct GroupedExprSyntax: ExprSyntax {
    let id: SyntaxId
    let exprs: [any ExprSyntax]
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}
