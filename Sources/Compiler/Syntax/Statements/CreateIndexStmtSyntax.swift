//
//  CreateIndexStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CreateIndexStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let unique: Bool
    let ifNotExists: Bool
    let schemaName: IdentifierSyntax?
    let name: IdentifierSyntax
    let table: IdentifierSyntax
    let indexedColumns: [IndexedColumnSyntax]
    let whereExpr: ExprSyntax?
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
