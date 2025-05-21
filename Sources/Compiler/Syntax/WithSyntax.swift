//
//  WithSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/20/25.
//

struct WithSyntax: Syntax {
    let id: SyntaxId
    let location: SourceLocation
    let recursive: Bool
    let ctes: [CommonTableExpressionSyntax]
}
