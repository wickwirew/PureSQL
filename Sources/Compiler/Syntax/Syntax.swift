//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//



protocol Syntax {
    var range: Range<Substring.Index> { get }
}

struct InsertStmt: Stmt, Syntax {
    let cte: CommonTableExpression?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableName
    let tableAlias: Identifier?
    let columns: [Identifier]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClause?
    let range: Range<Substring.Index>
    
    struct Values {
        let select: SelectStmt
        let upsertClause: UpsertClause?
    }
    
    enum Action: Equatable, Encodable {
        case replace
        case insert(Or?)
    }
    
    func accept<V>(visitor: inout V) throws -> V.Output where V : StmtVisitor {
        try visitor.visit(self)
    }
}

enum Or: Equatable, Encodable {
    case abort
    case fail
    case ignore
    case replace
    case rollback
}

struct ReturningClause: Syntax {
    let values: [Value]
    let range: Range<Substring.Index>

    enum Value {
        case expr(expr: Expression, alias: Identifier?)
        case all
    }
}

struct UpsertClause: Syntax {
    let confictTarget: ConflictTarget?
    let doAction: Do
    let range: Range<Substring.Index>
    
    struct ConflictTarget {
        let columns: [IndexedColumn]
        let condition: Expression?
    }
    
    enum Do {
        case nothing
        case updateSet(sets: [SetAction], where: Expression?)
    }
}

struct SetAction {
    let column: Column
    let expr: Expression
    
    enum Column {
        case single(Identifier)
        case list([Identifier])
    }
}

struct UpdateStmt: Syntax {
    let cte: CommonTableExpression?
    let cteRecursive: Bool
    let or: Or?
    let tableName: QualifiedTableName
    let sets: [SetAction]
    let from: From?
    let whereExpr: Expression?
    let returningClause: ReturningClause?
    let range: Range<Substring.Index>
}

struct QualifiedTableName: Syntax {
    let tableName: TableName
    let alias: Identifier?
    let indexed: Indexed?
    let range: Range<Substring.Index>
    
    enum Indexed {
        case not
        case by(Identifier)
    }
}

/// Used in a select and update. Not a centralized thing in
/// there docs but it shows up in both.
enum From {
    case tableOrSubqueries([TableOrSubquery])
    case join(JoinClause)
    
    init(table: Identifier) {
        self = .join(JoinClause(table: table))
    }
}
