//
//  IndexedColumnSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct IndexedColumnSyntax: Syntax {
    let id: SyntaxId
    let expr: ExpressionSyntax
    let collation: IdentifierSyntax?
    let order: OrderSyntax?
    
    var location: SourceLocation {
        let upper = order?.location ?? collation?.location ?? expr.location
        return expr.location.spanning(upper)
    }
    
    var columnName: IdentifierSyntax? {
        guard case let .column(column) = expr else { return nil }
        return column.column
    }
}
