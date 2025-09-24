//
//  CreateTriggerStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/17/25.
//

struct CreateTriggerStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    let isTemporary: Bool
    let ifNotExists: Bool
    let schemaName: IdentifierSyntax?
    let triggerName: IdentifierSyntax
    let modifier: Modifier?
    let action: Action
    let tableSchemaName: IdentifierSyntax?
    let tableName: IdentifierSyntax
    let when: ExprSyntax?
    let statements: [StmtSyntax]
    
    enum Modifier {
        case before
        case after
        case insteadOf
    }
    
    enum Action {
        case delete
        case insert
        case update(columns: [IdentifierSyntax]?)
    }
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}
