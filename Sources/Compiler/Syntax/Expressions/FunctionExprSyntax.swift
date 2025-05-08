//
//  FunctionExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct FunctionExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let table: IdentifierSyntax?
    let name: IdentifierSyntax
    let args: [ExpressionSyntax]
    let location: SourceLocation
    
    var description: String {
        return "\(table.map { "\($0)." } ?? "")\(name)(\(args.map(\.description).joined(separator: ", ")))"
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
