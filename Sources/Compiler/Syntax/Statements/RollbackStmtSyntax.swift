//
//  RollbackStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 6/14/25.
//

struct RollbackStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let savepoint: IdentifierSyntax?
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
