//
//  TableOrSubquerySyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/syntax/table-or-subquery.html
struct TableOrSubquerySyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        /// `foo.bar.baz`
        case table(Table)
        /// `foo(1)`
        case tableFunction(schema: IdentifierSyntax?, table: IdentifierSyntax, args: [any ExprSyntax], alias: AliasSyntax?)
        /// `(SELECT * FROM foo)`
        case subquery(SelectStmtSyntax, alias: AliasSyntax?)
        /// `(foo JOIN bar)`
        indirect case join(JoinClauseSyntax)
        /// Recusivly contains a list of more `TableOrSubquery`s
        /// `(foo, bar CROSS JOIN baz)`
        case tableOrSubqueries([TableOrSubquerySyntax])
    }

    struct Table {
        let schema: IdentifierSyntax?
        let name: IdentifierSyntax
        let alias: AliasSyntax?
        let indexedBy: IdentifierSyntax?
    }
}
