//
//  UpsertClauseSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct UpsertClauseSyntax: Syntax {
    let id: SyntaxId
    let confictTarget: ConflictTarget?
    let doAction: Do
    let location: SourceLocation

    struct ConflictTarget {
        let columns: [IndexedColumnSyntax]
        let condition: (any ExprSyntax)?
    }

    enum Do {
        case nothing
        case updateSet(sets: [SetActionSyntax], where: (any ExprSyntax)?)
    }
}
