//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//



protocol Syntax {
    var range: Range<Substring.Index> { get }
}

/*
 InsertStmtSyntax
    cteRecursive = true
    values
        SelectStmtSyntax
   
 
 CreateTableStatementSyntax
    name: user
    isTemporary: true
    onlyIfExists: true
    kind:
        SelectStatementSytax
            selec
 */



struct InsertStmtSyntax: Syntax, Equatable {
    let cte: Indirect<CommonTableExpression>?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableName
    let tableAlias: IdentifierSyntax
    let values: Values? // if nil, default values
    let returningClause: ReturningClauseSyntax?
    let range: Range<Substring.Index>
    
    struct Values: Equatable {
        let select: SelectStmt
        let upsertClause: UpsertClauseSyntax?
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



struct ReturningClauseSyntax: Syntax, Equatable {
    let values: [Value]
    let range: Range<Substring.Index>

    struct Value: Equatable {
        let expr: Expression
        let alias: IdentifierSyntax?
    }
}

struct UpsertClauseSyntax: Syntax, Equatable {
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
        
        init(column: Column, expr: Expression) {
            self.column = column
            self.expr = expr
        }
    }
    
    enum Column: Equatable {
        case single(Substring)
        case list([Substring])
    }
}
