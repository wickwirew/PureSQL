//
//  BetweenExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/lang_expr.html
struct BetweenExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let not: Bool
    let value: ExpressionSyntax
    let lower: ExpressionSyntax
    let upper: ExpressionSyntax
    
    var location: SourceLocation {
        return value.location.spanning(upper.location)
    }
    
    var description: String {
        return "(\(value)\(not ? " NOT" : "") BETWEEN \(lower) AND \(upper))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
