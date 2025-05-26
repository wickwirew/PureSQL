//
//  TableOrSubquerySyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct TableOrSubquerySyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case table(Table)
        case tableFunction(schema: IdentifierSyntax?, table: IdentifierSyntax, args: [ExpressionSyntax], alias: AliasSyntax?)
        case subquery(SelectStmtSyntax, alias: AliasSyntax?)
        indirect case join(JoinClauseSyntax)
        case tableOrSubqueries([TableOrSubquerySyntax], alias: AliasSyntax?)
    }

    struct Table {
        let schema: IdentifierSyntax?
        let name: IdentifierSyntax
        let alias: AliasSyntax?
        let indexedBy: IdentifierSyntax?
    }
}
