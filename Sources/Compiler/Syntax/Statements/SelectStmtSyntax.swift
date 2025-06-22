//
//  SelectStmtSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct SelectStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let with: WithSyntax?
    let selects: Indirect<Selects>
    let orderBy: [OrderingTermSyntax]
    let limit: Limit?
    let location: SourceLocation

    enum Selects {
        case single(SelectCoreSyntax)
        indirect case compound(SelectCoreSyntax, CompoundOperatorSyntax, Selects)
    }

    struct Limit {
        let expr: any ExprSyntax
        let offset: (any ExprSyntax)?
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
