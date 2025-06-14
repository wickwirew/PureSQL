//
//  OrderingTermSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct OrderingTermSyntax: Syntax {
    let id: SyntaxId
    let expr: any ExprSyntax
    let order: OrderSyntax?
    let nulls: Nulls?
    let location: SourceLocation

    enum Nulls {
        case first
        case last
    }
}
