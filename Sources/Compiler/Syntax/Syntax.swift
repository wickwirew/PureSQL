//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//



protocol Syntax {
    var range: Range<Substring.Index> { get }
}

struct InsertStmt: Syntax, Equatable {
    let cte: CommonTableExpression?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableName
    let tableAlias: IdentifierSyntax?
    let columns: [IdentifierSyntax]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClause?
    let range: Range<Substring.Index>
    
    struct Values: Equatable {
        let select: SelectStmt
        let upsertClause: UpsertClause?
    }
    
    enum Action: Equatable, Encodable {
        case replace
        case insert(Or?)
    }
    
    enum Or: Equatable, Encodable {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
}



struct ReturningClause: Syntax, Equatable {
    let values: [Value]
    let range: Range<Substring.Index>

    enum Value: Equatable {
        case expr(expr: Expression, alias: IdentifierSyntax?)
        case all
    }
}

struct UpsertClause: Syntax, Equatable {
    let confictTarget: ConflictTarget?
    let doAction: Do
    let range: Range<Substring.Index>
    
    struct ConflictTarget: Equatable {
        let columns: [IndexedColumn]
        let condition: Expression?
    }
    
    enum Do: Equatable {
        case nothing
        case updateSet(sets: [SetAction], where: Expression?)
    }
    
    struct SetAction: Equatable {
        let column: Column
        let expr: Expression
    }
    
    enum Column: Equatable {
        case single(IdentifierSyntax)
        case list([IdentifierSyntax])
    }
}
