//
//  DeleteStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct DeleteStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let with: WithSyntax?
    let table: QualifiedTableNameSyntax
    let whereExpr: (any ExprSyntax)?
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
