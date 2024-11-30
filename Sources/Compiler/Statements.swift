//
//  Statements.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import OrderedCollections

protocol StmtVisitor {
    associatedtype Output
    mutating func visit(_ stmt: borrowing CreateTableStmt) -> Output
    mutating func visit(_ stmt: borrowing AlterTableStmt) -> Output
    mutating func visit(_ stmt: borrowing EmptyStmt) -> Output
    mutating func visit(_ stmt: borrowing SelectStmt) -> Output
}

protocol Stmt {
    func accept<V: StmtVisitor>(visitor: inout V) -> V.Output
}

struct CreateTableStmt: Equatable, Stmt {
    let name: Identifier
    let schemaName: Identifier?
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: Kind
    let constraints: [TableConstraint]
    let options: TableOptions
    
    enum Kind: Equatable {
        case select(SelectStmt)
        case columns(OrderedDictionary<Identifier, ColumnDef>)
    }
    
    init(
        name: Identifier,
        schemaName: Identifier?,
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
    
    func accept<V>(visitor: inout V) -> V.Output where V : StmtVisitor {
        visitor.visit(self)
    }
}

struct AlterTableStmt: Equatable, Stmt {
    let name: Identifier
    let schemaName: Identifier?
    let kind: Kind
    
    enum Kind: Equatable {
        case rename(Identifier)
        case renameColumn(Identifier, Identifier)
        case addColumn(ColumnDef)
        case dropColumn(Identifier)
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : StmtVisitor {
        visitor.visit(self)
    }
}

struct EmptyStmt: Equatable, Stmt {
    init() {}
    
    func accept<V>(visitor: inout V) -> V.Output where V : StmtVisitor {
        visitor.visit(self)
    }
}
