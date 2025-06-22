//
//  CreateViewStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CreateViewStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let temp: Bool
    let ifNotExists: Bool
    let schemaName: IdentifierSyntax?
    let name: IdentifierSyntax
    let columnNames: [IdentifierSyntax]
    let select: SelectStmtSyntax
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
