//
//  Syntax.swift
//  Feather
//
//  Created by Wes Wickwire on 11/12/24.
//

struct SyntaxId: Hashable, Sendable {
    private let rawValue: Int
    
    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

protocol Syntax {
    var id: SyntaxId { get }
    var range: SourceLocation { get }
}

struct InsertStmtSyntax: StmtSyntax, Syntax {
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableNameSyntax
    let tableAlias: AliasSyntax?
    let columns: [IdentifierSyntax]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClauseSyntax?
    let range: SourceLocation

    struct Values: Syntax {
        let id: SyntaxId
        let select: SelectStmtSyntax
        let upsertClause: UpsertClauseSyntax?
        
        var range: SourceLocation {
            let lower = select.range
            let upper = upsertClause?.range ?? select.range
            return lower.spanning(upper)
        }
    }

    struct Action: Syntax {
        let id: SyntaxId
        let kind: Kind
        let range: SourceLocation
        
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
    let id: SyntaxId
    let kind: Kind
    let range: SourceLocation
    
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
    let id: SyntaxId
    let values: [Value]
    let range: SourceLocation

    enum Value {
        case expr(expr: ExpressionSyntax, alias: AliasSyntax?)
        case all
    }
}

struct UpsertClauseSyntax: Syntax {
    let id: SyntaxId
    let confictTarget: ConflictTarget?
    let doAction: Do
    let range: SourceLocation

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
    let id: SyntaxId
    let column: Column
    let expr: ExpressionSyntax
    
    var range: SourceLocation {
        return column.range.spanning(expr.range)
    }

    enum Column {
        case single(IdentifierSyntax)
        case list([IdentifierSyntax])
        
        var range: SourceLocation {
            switch self {
            case .single(let i): return i.range
            case .list(let l):
                guard let lower = l.first?.range,
                      let upper = l.last?.range else {
                    return .empty
                }
                
                return lower.spanning(upper)
            }
        }
    }
}

struct UpdateStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let or: OrSyntax?
    let tableName: QualifiedTableNameSyntax
    let sets: [SetActionSyntax]
    let from: FromSyntax?
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let range: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct QualifiedTableNameSyntax: Syntax {
    let id: SyntaxId
    let tableName: TableNameSyntax
    let alias: AliasSyntax?
    let indexed: Indexed?
    let range: SourceLocation

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
