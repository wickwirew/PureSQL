//
//  InsertStmtSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct InsertStmtSyntax: StmtSyntax, Syntax {
    let id: SyntaxId
    let with: WithSyntax?
    let action: Action
    let tableName: TableNameSyntax
    let tableAlias: AliasSyntax?
    let columns: [IdentifierSyntax]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation

    struct Values: Syntax {
        let id: SyntaxId
        let select: SelectStmtSyntax
        let upsertClause: UpsertClauseSyntax?
        
        var location: SourceLocation {
            let lower = select.location
            let upper = upsertClause?.location ?? select.location
            return lower.spanning(upper)
        }
    }

    struct Action: Syntax {
        let id: SyntaxId
        let kind: Kind
        let location: SourceLocation
        
        enum Kind {
            case replace
            case insert(OrSyntax?)
        }
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
