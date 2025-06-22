//
//  IndexedColumnSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct IndexedColumnSyntax: Syntax {
    let id: SyntaxId
    let expr: any ExprSyntax
    let collation: IdentifierSyntax?
    let order: OrderSyntax?

    var location: SourceLocation {
        let upper = order?.location ?? collation?.location ?? expr.location
        return expr.location.spanning(upper)
    }

    var columnName: IdentifierSyntax? {
        guard let column = expr as? ColumnExprSyntax,
              case let .column(name) = column.column else { return nil }
        return name
    }
}
