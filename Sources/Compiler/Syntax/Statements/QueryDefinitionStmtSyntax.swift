//
//  QueryDefinitionStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct QueryDefinitionStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let name: IdentifierSyntax
    let input: IdentifierSyntax?
    let output: IdentifierSyntax?
    let statement: any StmtSyntax
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
