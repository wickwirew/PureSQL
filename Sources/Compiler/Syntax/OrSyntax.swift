//
//  OrSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct OrSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind: String {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
}
