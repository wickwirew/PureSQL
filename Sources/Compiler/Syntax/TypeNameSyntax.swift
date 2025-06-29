//
//  TypeNameSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct TypeNameSyntax: Syntax, CustomStringConvertible, Sendable {
    let id: SyntaxId
    let name: IdentifierSyntax
    let arg1: SignedNumberSyntax?
    let arg2: SignedNumberSyntax?
    let alias: Alias?
    let location: SourceLocation
    
    struct Alias: CustomStringConvertible {
        let name: AliasSyntax
        let using: IdentifierSyntax?
        
        var description: String {
            if let using {
                return "\(name) USING \(using)"
            } else {
                return name.description
            }
        }
    }

    var description: String {
        let type = if let arg1, let arg2 {
            "\(name)(\(arg1), \(arg2))"
        } else if let arg1 {
            "\(name)(\(arg1))"
        } else {
            name.description
        }

        if let alias {
            return "\(type) AS \(alias)"
        } else {
            return type
        }
    }
}
