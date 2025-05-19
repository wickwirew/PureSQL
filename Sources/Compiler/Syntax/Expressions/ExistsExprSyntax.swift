//
//  ExistsExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/18/25.
//

struct ExistsExprSyntax: ExprSyntax {
    let id: SyntaxId
    let not: Bool
    let location: SourceLocation
    let select: SelectStmtSyntax
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        visitor.visit(self)
    }
}
