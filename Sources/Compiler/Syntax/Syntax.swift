//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//

protocol Syntax {
    var range: Range<Substring.Index> { get }
}

struct InsertStmtSyntax: StmtSyntax, Syntax {
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableNameSyntax
    let tableAlias: IdentifierSyntax?
    let columns: [IdentifierSyntax]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClauseSyntax?
    let range: Range<Substring.Index>

    struct Values: Syntax {
        let select: SelectStmtSyntax
        let upsertClause: UpsertClauseSyntax?
        
        var range: Range<Substring.Index> {
            let lower = select.range.lowerBound
            let upper = upsertClause?.range.upperBound ?? select.range.upperBound
            return lower..<upper
        }
    }

    struct Action: Syntax {
        let kind: Kind
        let range: Range<Substring.Index>
        
        enum Kind {
            case replace
            case insert(OrSyntax?)
        }
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct OrSyntax: Syntax, CustomStringConvertible {
    let kind: Kind
    let range: Range<Substring.Index>
    
    enum Kind: String {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
    
    var description: String {
        return kind.rawValue
    }
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

struct SetActionSyntax: Syntax {
    let column: Column
    let expr: ExpressionSyntax
    
    var range: Range<Substring.Index> {
        return column.range.lowerBound..<expr.range.upperBound
    }

    enum Column: Syntax {
        case single(IdentifierSyntax)
        case list([IdentifierSyntax])
        
        var range: Range<Substring.Index> {
            switch self {
            case .single(let i): return i.range
            case .list(let l):
                guard let lower = l.first?.range.lowerBound,
                      let upper = l.last?.range.upperBound else {
                    return .empty
                }
                
                return lower..<upper
            }
        }
    }
}

struct UpdateStmtSyntax: StmtSyntax {
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let or: OrSyntax?
    let tableName: QualifiedTableNameSyntax
    let sets: [SetActionSyntax]
    let from: FromSyntax?
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let range: Range<Substring.Index>
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
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
