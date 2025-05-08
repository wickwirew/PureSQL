//
//  ReturningClauseSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ReturningClauseSyntax: Syntax {
    let id: SyntaxId
    let values: [Value]
    let location: SourceLocation

    enum Value {
        case expr(expr: ExpressionSyntax, alias: AliasSyntax?)
        case all
    }
}
