//
//  CastExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CastExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let expr: ExpressionSyntax
    let ty: TypeNameSyntax
    let location: SourceLocation
    
    var description: String {
        return "CAST(\(expr) AS \(ty))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
