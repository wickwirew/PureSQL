//
//  InfixExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/lang_expr.html
struct InfixExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let lhs: ExpressionSyntax
    let `operator`: OperatorSyntax
    let rhs: ExpressionSyntax
    
    var location: SourceLocation {
        return lhs.location.spanning(rhs.location)
    }
    
    var description: String {
        return "(\(lhs) \(`operator`) \(rhs))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
