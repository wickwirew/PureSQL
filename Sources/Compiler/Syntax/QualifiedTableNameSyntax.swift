//
//  QualifiedTableNameSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct QualifiedTableNameSyntax: Syntax {
    let id: SyntaxId
    let tableName: TableNameSyntax
    let alias: AliasSyntax?
    let indexed: Indexed?
    let location: SourceLocation

    enum Indexed {
        case not
        case by(IdentifierSyntax)
    }
}
