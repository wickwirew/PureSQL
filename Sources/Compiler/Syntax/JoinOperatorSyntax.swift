//
//  JoinOperatorSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct JoinOperatorSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        case comma
        case join
        case natural
        case left(natural: Bool = false, outer: Bool = false)
        case right(natural: Bool = false, outer: Bool = false)
        case full(natural: Bool = false, outer: Bool = false)
        case inner(natural: Bool = false)
        case cross
    }
}
