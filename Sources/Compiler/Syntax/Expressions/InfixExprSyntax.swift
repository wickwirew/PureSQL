//
//  InfixExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/lang_expr.html
struct InfixExprSyntax: ExprSyntax {
    let id: SyntaxId
    let lhs: any ExprSyntax
    let `operator`: OperatorSyntax
    let rhs: any ExprSyntax
    
    var location: SourceLocation {
        return lhs.location.spanning(rhs.location)
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
