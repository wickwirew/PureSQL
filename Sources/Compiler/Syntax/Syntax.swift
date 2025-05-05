//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//

struct SyntaxId: Hashable, Sendable {
    private let rawValue: Int
    
    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

protocol Syntax {
    var id: SyntaxId { get }
    var location: SourceLocation { get }
}

/// Used in a select and update. Not a centralized thing in
/// there docs but it shows up in both.
enum FromSyntax {
    case tableOrSubqueries([TableOrSubquerySyntax])
    case join(JoinClauseSyntax)
}
