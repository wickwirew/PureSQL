//
//  UpdateStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct UpdateStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let with: WithSyntax?
    let or: OrSyntax?
    let tableName: QualifiedTableNameSyntax
    let sets: [SetActionSyntax]
    let from: FromSyntax?
    let whereExpr: (any ExprSyntax)?
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
