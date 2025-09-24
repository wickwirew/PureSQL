//
//  AlterTableStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct AlterTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        case rename(IdentifierSyntax)
        case renameColumn(IdentifierSyntax, IdentifierSyntax)
        case addColumn(ColumnDefSyntax)
        case dropColumn(IdentifierSyntax)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
