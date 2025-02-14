//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//

protocol Syntax {
    var range: Range<Substring.Index> { get }
}

struct InsertStmtSyntax: Stmt, Syntax {
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableNameSyntax
    let tableAlias: IdentifierSyntax?
    let columns: [IdentifierSyntax]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClauseSyntax?
    let range: Range<Substring.Index>

    struct Values {
        let select: SelectStmtSyntax
        let upsertClause: UpsertClauseSyntax?
    }

    enum Action: Equatable, Encodable {
        case replace
        case insert(OrSyntax?)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtVisitor {
        visitor.visit(self)
    }
}

enum OrSyntax: Equatable, Encodable {
    case abort
    case fail
    case ignore
    case replace
    case rollback
}

struct ReturningClauseSyntax: Syntax {
    let values: [Value]
    let range: Range<Substring.Index>

    enum Value {
        case expr(expr: ExpressionSyntax, alias: IdentifierSyntax?)
        case all
    }
}

struct UpsertClauseSyntax: Syntax {
    let confictTarget: ConflictTarget?
    let doAction: Do
    let range: Range<Substring.Index>

    struct ConflictTarget {
        let columns: [IndexedColumnSyntax]
        let condition: ExpressionSyntax?
    }

    enum Do {
        case nothing
        case updateSet(sets: [SetActionSyntax], where: ExpressionSyntax?)
    }
}

struct SetActionSyntax {
    let column: Column
    let expr: ExpressionSyntax

    enum Column {
        case single(IdentifierSyntax)
        case list([IdentifierSyntax])
    }
}

struct UpdateStmtSyntax: Syntax {
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let or: OrSyntax?
    let tableName: QualifiedTableNameSyntax
    let sets: [SetActionSyntax]
    let from: FromSyntax?
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let range: Range<Substring.Index>
}

struct QualifiedTableNameSyntax: Syntax {
    let tableName: TableNameSyntax
    let alias: IdentifierSyntax?
    let indexed: Indexed?
    let range: Range<Substring.Index>

    enum Indexed {
        case not
        case by(IdentifierSyntax)
    }
}

/// Used in a select and update. Not a centralized thing in
/// there docs but it shows up in both.
enum FromSyntax {
    case tableOrSubqueries([TableOrSubquerySyntax])
    case join(JoinClauseSyntax)
}
