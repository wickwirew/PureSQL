//
//  DropViewStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/18/25.
//

struct DropViewStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let ifExists: Bool
    let schemaName: IdentifierSyntax?
    let viewName: IdentifierSyntax

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
