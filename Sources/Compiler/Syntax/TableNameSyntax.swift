//
//  TableNameSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct TableNameSyntax: Syntax, Hashable, CustomStringConvertible {
    let id: SyntaxId
    let schema: Schema
    let name: IdentifierSyntax

    enum Schema: Hashable {
        case main
        case other(IdentifierSyntax)
    }

    var description: String {
        switch schema {
        case .main:
            return name.description
        case let .other(schema):
            return "\(schema).\(name)"
        }
    }

    var location: SourceLocation {
        return switch schema {
        case .main: name.location
        case let .other(schema): schema.location.spanning(name.location)
        }
    }
}
