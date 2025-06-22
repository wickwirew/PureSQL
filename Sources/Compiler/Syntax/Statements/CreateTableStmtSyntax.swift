//
//  CreateTableStmtSyntax.swift
//  Otter
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
    let location: SourceLocation

    typealias Columns = OrderedDictionary<IdentifierSyntax, ColumnDefSyntax>

    var constraints: [TableConstraintSyntax]? {
        guard case let .columns(_, constraints, _) = kind else { return nil }
        return constraints
    }

    var options: TableOptionsSyntax? {
        guard case let .columns(_, _, options) = kind else { return nil }
        return options
    }

    enum Kind {
        case select(SelectStmtSyntax)
        case columns(Columns, constraints: [TableConstraintSyntax], options: TableOptionsSyntax)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
