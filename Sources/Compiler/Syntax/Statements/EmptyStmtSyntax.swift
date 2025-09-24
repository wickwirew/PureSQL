//
//  EmptyStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

/// Just an empty `;` statement. Silly but useful in the parser.
struct EmptyStmtSyntax: Equatable, StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
