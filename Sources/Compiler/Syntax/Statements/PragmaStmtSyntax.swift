//
//  PragmaStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct PragmaStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let schema: IdentifierSyntax?
    let name: IdentifierSyntax
    let value: ExprSyntax?
    let isFunctionCall: Bool
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
