//
//  JoinClauseSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct JoinClauseSyntax: Syntax {
    let id: SyntaxId
    let tableOrSubquery: TableOrSubquerySyntax
    let joins: [Join]
    let location: SourceLocation

    struct Join {
        let op: JoinOperatorSyntax
        let tableOrSubquery: TableOrSubquerySyntax
        let constraint: JoinConstraintSyntax
    }
}
