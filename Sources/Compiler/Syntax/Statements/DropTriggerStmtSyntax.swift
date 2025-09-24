//
//  DropTriggerStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/17/25.
//

struct DropTriggerStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let ifExists: Bool
    let schemaName: IdentifierSyntax?
    let triggerName: IdentifierSyntax

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
