//
//  GroupedExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

/// A single or many expressions in parenthesis
/// 
/// https://www.sqlite.org/lang_expr.html
struct GroupedExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let exprs: [ExpressionSyntax]
    let location: SourceLocation
    
    var description: String {
        return "(\(exprs.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}
