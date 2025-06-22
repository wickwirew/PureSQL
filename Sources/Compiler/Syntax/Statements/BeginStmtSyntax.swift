//
//  BeginStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 6/14/25.
//

struct BeginStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let kind: Kind?

    enum Kind {
        case deferred
        case immediate
        case exclusive
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
