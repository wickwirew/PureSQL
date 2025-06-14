//
//  SelectCoreSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/syntax/select-core.html
enum SelectCoreSyntax {
    /// SELECT column FROM foo
    case select(Select)
    /// VALUES (foo, bar baz)
    case values([[any ExprSyntax]])

    struct Select {
        let distinct: Bool
        let columns: [ResultColumnSyntax]
        let from: FromSyntax?
        let `where`: (any ExprSyntax)?
        let groupBy: GroupBy?
        let windows: [Window]

        init(
            distinct: Bool = false,
            columns: [ResultColumnSyntax],
            from: FromSyntax?,
            where: (any ExprSyntax)? = nil,
            groupBy: GroupBy? = nil,
            windows: [Window] = []
        ) {
            self.distinct = distinct
            self.columns = columns
            self.from = from
            self.where = `where`
            self.groupBy = groupBy
            self.windows = windows
        }
    }

    struct Window {
        let name: IdentifierSyntax
        let window: WindowDefinitionSyntax
    }

    struct GroupBy {
        let expressions: [any ExprSyntax]
        let having: (any ExprSyntax)?

        enum Nulls {
            case first
            case last
        }
    }
}
