//
//  UpdateStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct UpdateStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let or: OrSyntax?
    let tableName: QualifiedTableNameSyntax
    let sets: [SetActionSyntax]
    let from: FromSyntax?
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
