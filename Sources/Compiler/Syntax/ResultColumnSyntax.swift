//
//  ResultColumnSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ResultColumnSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        /// Note: This will represent even just a single column select
        case expr(ExpressionSyntax, as: AliasSyntax?)
        /// `*` or `table.*`
        case all(table: IdentifierSyntax?)
    }
}
