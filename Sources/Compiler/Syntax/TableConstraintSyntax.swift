//
//  TableConstraintSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct TableConstraintSyntax: Syntax {
    let id: SyntaxId
    let name: IdentifierSyntax?
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        case primaryKey([IndexedColumnSyntax], ConfictClauseSyntax)
        case unique(IndexedColumnSyntax, ConfictClauseSyntax)
        case check(ExpressionSyntax)
        case foreignKey([IdentifierSyntax], ForeignKeyClauseSyntax)
    }
}
