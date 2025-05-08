//
//  SelectExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

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
