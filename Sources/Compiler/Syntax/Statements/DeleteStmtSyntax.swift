//
//  DeleteStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct DeleteStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let table: QualifiedTableNameSyntax
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
