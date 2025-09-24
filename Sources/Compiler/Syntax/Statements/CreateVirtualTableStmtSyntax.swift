//
//  CreateVirtualTableStmtSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CreateVirtualTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let ifNotExists: Bool
    let tableName: TableNameSyntax
    let module: Module
    let moduleName: IdentifierSyntax
    let arguments: [ModuleArgument]
    let location: SourceLocation
    
    enum Module {
        case fts5
        case unknown
    }
    
    enum ModuleArgument {
        case fts5Column(
            name: IdentifierSyntax,
            typeName: TypeNameSyntax?,
            notNull: SourceLocation?,
            unindexed: Bool
        )
        case fts5Option(name: IdentifierSyntax, value: ExprSyntax)
        case unknown
    }
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
