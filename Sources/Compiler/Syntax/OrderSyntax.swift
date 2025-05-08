//
//  OrderSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct OrderSyntax: Syntax, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind: String {
        case asc
        case desc
    }
    
    var description: String {
        return kind.rawValue
    }
}
