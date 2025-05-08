//
//  ColumnConstraintSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ColumnConstraintSyntax: Syntax {
    let id: SyntaxId
    let name: IdentifierSyntax?
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        case primaryKey(order: OrderSyntax?, ConfictClauseSyntax, autoincrement: Bool)
        case notNull(ConfictClauseSyntax)
        case unique(ConfictClauseSyntax)
        case check(ExpressionSyntax)
        case `default`(ExpressionSyntax)
        case collate(IdentifierSyntax)
        case foreignKey(ForeignKeyClauseSyntax)
        case generated(ExpressionSyntax, GeneratedKind?)
    }

    enum GeneratedKind {
        case stored
        case virtual
    }

    var isPkConstraint: Bool {
        switch kind {
        case .primaryKey: return true
        default: return false
        }
    }

    var isNotNullConstraint: Bool {
        switch kind {
        case .notNull: return true
        default: return false
        }
    }
}
