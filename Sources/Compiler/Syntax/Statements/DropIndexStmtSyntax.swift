//
//  DropIndexStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct DropIndexStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let ifExists: Bool
    let schemaName: IdentifierSyntax?
    let name: IdentifierSyntax
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
