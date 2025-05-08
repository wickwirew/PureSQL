//
//  CommonTableExpressionSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CommonTableExpressionSyntax: Syntax {
    let id: SyntaxId
    let table: IdentifierSyntax
    let columns: [IdentifierSyntax]
    let materialized: Bool
    let select: SelectStmtSyntax
    let location: SourceLocation
}
