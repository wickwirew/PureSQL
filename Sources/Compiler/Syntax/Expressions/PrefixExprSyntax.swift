//
//  PrefixExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/lang_expr.html
struct PrefixExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let `operator`: OperatorSyntax
    let rhs: ExpressionSyntax
    
    var description: String {
        return "(\(`operator`)\(rhs))"
    }
    
    var location: SourceLocation {
        return `operator`.location.spanning(rhs.location)
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
