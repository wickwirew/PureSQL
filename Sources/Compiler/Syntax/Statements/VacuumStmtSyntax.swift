//
//  VacuumStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/14/25.
//

struct VacuumStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let schema: IdentifierSyntax?
    let fileName: IdentifierSyntax?

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
