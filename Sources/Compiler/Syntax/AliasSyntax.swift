//
//  AliasSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct AliasSyntax: Syntax, CustomStringConvertible {
    let id: SyntaxId
    let identifier: IdentifierSyntax
    let location: SourceLocation

    var description: String {
        return identifier.description
    }
}
