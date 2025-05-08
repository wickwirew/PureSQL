//
//  ForeignKeyClauseSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ForeignKeyClauseSyntax: Syntax {
    let id: SyntaxId
    let foreignTable: IdentifierSyntax
    let foreignColumns: [IdentifierSyntax]
    let actions: [Action]
    let location: SourceLocation

    enum Action {
        case onDo(On, Do)
        indirect case match(IdentifierSyntax, [Action])
        case deferrable(Deferrable?)
        case notDeferrable(Deferrable?)
    }

    enum On {
        case delete
        case update
    }

    enum Do {
        case setNull
        case setDefault
        case cascade
        case restrict
        case noAction
    }

    enum Deferrable {
        case initiallyDeferred
        case initiallyImmediate
    }
}
