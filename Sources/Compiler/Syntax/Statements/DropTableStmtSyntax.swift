//
//  DropTableStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct DropTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let ifExists: Bool
    let tableName: TableNameSyntax
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
