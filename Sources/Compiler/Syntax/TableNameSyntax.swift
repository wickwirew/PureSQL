//
//  TableNameSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct TableNameSyntax: Syntax, Hashable, CustomStringConvertible {
    let id: SyntaxId
    let schema: IdentifierSyntax?
    let name: IdentifierSyntax

    enum Schema: Hashable {
        case main
        case other(IdentifierSyntax)
    }

    var description: String {
        if let schema {
            return "\(schema).\(name)"
        } else {
            return name.description
        }
    }

    var location: SourceLocation {
        if let schema {
            return schema.location.spanning(name.location)
        } else {
            return name.location
        }
    }
}
