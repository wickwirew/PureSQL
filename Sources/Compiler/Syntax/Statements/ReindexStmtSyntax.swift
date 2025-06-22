//
//  ReindexStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ReindexStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let schemaName: IdentifierSyntax?
    // Note: This can be the collation, index or table name
    let name: IdentifierSyntax?
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
