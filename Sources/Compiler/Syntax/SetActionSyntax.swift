//
//  SetActionSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct SetActionSyntax: Syntax {
    let id: SyntaxId
    let column: Column
    let expr: any ExprSyntax

    var location: SourceLocation {
        return column.location.spanning(expr.location)
    }

    enum Column {
        case single(IdentifierSyntax)
        case list([IdentifierSyntax])

        var location: SourceLocation {
            switch self {
            case let .single(i): return i.location
            case let .list(l):
                guard let lower = l.first?.location,
                      let upper = l.last?.location
                else {
                    return .empty
                }

                return lower.spanning(upper)
            }
        }
    }
}
