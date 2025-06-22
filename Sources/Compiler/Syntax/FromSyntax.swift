//
//  FromSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

/// Used in a select and update. Not a centralized thing in
/// there docs but it shows up in both.
enum FromSyntax {
    case tableOrSubqueries([TableOrSubquerySyntax])
    case join(JoinClauseSyntax)
}
