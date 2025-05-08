//
//  ColumnDefSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ColumnDefSyntax: Syntax {
    let id: SyntaxId
    var name: IdentifierSyntax
    var type: TypeNameSyntax
    var constraints: [ColumnConstraintSyntax]
    
    var location: SourceLocation {
        let upper = constraints.last?.location ?? type.location
        return name.location.spanning(upper)
    }
}
