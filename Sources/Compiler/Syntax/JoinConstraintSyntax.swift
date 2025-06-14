//
//  JoinConstraintSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct JoinConstraintSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case on(any ExprSyntax)
        case using([IdentifierSyntax])
        case none

        var on: (any ExprSyntax)? {
            if case let .on(e) = self { return e }
            return nil
        }
    }
}
