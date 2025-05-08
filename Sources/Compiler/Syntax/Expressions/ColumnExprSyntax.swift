//
//  ColumnExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ColumnExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let schema: IdentifierSyntax?
    let table: IdentifierSyntax?
    let column: IdentifierSyntax // TODO: Support *
    
    var description: String {
        return [schema, table, column]
            .compactMap { $0?.value }
            .joined(separator: ".")
    }
    
    var location: SourceLocation {
        let first = schema ?? table ?? column
        return first.location.spanning(column.location)
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
