//
//  InvalidExprSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

/// An expression to throw in whenever an expression is unable to be parsed
/// so we do not have to stop the parsing process.
struct InvalidExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let location: SourceLocation

    var description: String {
        return "<<invalid>>"
    }

    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}
