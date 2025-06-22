//
//  CaseWhenThenExprSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CaseWhenThenExprSyntax: ExprSyntax {
    let id: SyntaxId
    let `case`: (any ExprSyntax)?
    let whenThen: [WhenThen]
    let `else`: (any ExprSyntax)?
    let location: SourceLocation

    struct WhenThen {
        let when: any ExprSyntax
        let then: any ExprSyntax
    }

    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
