//
//  UpsertClauseSyntax.swift
//  Feather
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
        let condition: ExpressionSyntax?
    }

    enum Do {
        case nothing
        case updateSet(sets: [SetActionSyntax], where: ExpressionSyntax?)
    }
}
