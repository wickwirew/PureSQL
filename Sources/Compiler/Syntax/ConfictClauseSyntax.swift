//
//  ConfictClauseSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

enum ConfictClauseSyntax {
    case rollback
    case abort
    case fail
    case ignore
    case replace
    // Note: Normally would rather make `ConflictClause` `nil` in this
    // case but the clause according to sqlites documentation no clause
    // is still a part of the clause.
    // https://www.sqlite.org/syntax/conflict-clause.html
    case none
}
