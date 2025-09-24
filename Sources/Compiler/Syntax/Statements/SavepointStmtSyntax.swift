//
//  SavepointStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/14/25.
//

struct SavepointStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let name: IdentifierSyntax

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
