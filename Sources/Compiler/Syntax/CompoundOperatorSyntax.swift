//
//  CompoundOperatorSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CompoundOperatorSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case union
        case unionAll
        case intersect
        case except
    }
}
