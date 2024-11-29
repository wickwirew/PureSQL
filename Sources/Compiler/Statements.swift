//
//  Statements.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import OrderedCollections

// TODO: Make not once the modules are merged
protocol StatementVisitor {
    associatedtype Output
    mutating func visit(_ stmt: borrowing CreateTableStatement) -> Output
    mutating func visit(_ stmt: borrowing AlterTableStatement) -> Output
    mutating func visit(_ stmt: borrowing EmptyStatement) -> Output
    mutating func visit(_ stmt: borrowing SelectStmt) -> Output
}

protocol Statement {
    func accept<V: StatementVisitor>(visitor: inout V) -> V.Output
}

struct CreateTableStatement: Equatable, Statement {
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: Kind
    let constraints: [TableConstraint]
    let options: TableOptions
    
    enum Kind: Equatable {
        case select(SelectStmt)
        case columns(OrderedDictionary<IdentifierSyntax, ColumnDef>)
    }
    
    init(
        name: IdentifierSyntax,
        schemaName: IdentifierSyntax?,
        isTemporary: Bool,
        onlyIfExists: Bool,
        kind: Kind,
        constraints: [TableConstraint],
        options: TableOptions
    ) {
        self.name = name
        self.schemaName = schemaName
        self.isTemporary = isTemporary
        self.onlyIfExists = onlyIfExists
        self.kind = kind
        self.constraints = constraints
        self.options = options
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}

struct AlterTableStatement: Equatable, Statement {
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let kind: Kind
    
    enum Kind: Equatable {
        case rename(IdentifierSyntax)
        case renameColumn(IdentifierSyntax, IdentifierSyntax)
        case addColumn(ColumnDef)
        case dropColumn(IdentifierSyntax)
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}

struct EmptyStatement: Equatable, Statement {
    init() {}
    
    func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}
