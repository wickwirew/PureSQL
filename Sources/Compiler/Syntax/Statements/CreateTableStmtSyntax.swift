//
//  CreateTableStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

import OrderedCollections

struct CreateTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: Kind
    let constraints: [TableConstraintSyntax]
    let options: TableOptionsSyntax
    let location: SourceLocation

    typealias Columns = OrderedDictionary<IdentifierSyntax, ColumnDefSyntax>
    
    enum Kind {
        case select(SelectStmtSyntax)
        case columns(Columns)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
