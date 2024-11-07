//
//  Statements.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import OrderedCollections

public protocol StatementVisitor {
    associatedtype Output
    mutating func visit(_ stmt: borrowing CreateTableStatement) -> Output
    mutating func visit(_ stmt: borrowing AlterTableStatement) -> Output
    mutating func visit(_ stmt: borrowing EmptyStatement) -> Output
}

public protocol Statement {
    func accept<V: StatementVisitor>(visitor: inout V) -> V.Output
}

public struct CreateTableStatement: Equatable, Statement {
    public let name: IdentifierSyntax
    public let schemaName: IdentifierSyntax?
    public let isTemporary: Bool
    public let onlyIfExists: Bool
    public let kind: Kind
    public let constraints: [TableConstraint]
    public let options: TableOptions
    
    public enum Kind: Equatable {
        case select(SelectStmt)
        case columns(OrderedDictionary<IdentifierSyntax, ColumnDef>)
    }
    
    public init(
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
    
    public func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}

public struct AlterTableStatement: Equatable, Statement {
    public let name: IdentifierSyntax
    public let schemaName: IdentifierSyntax?
    public let kind: Kind
    
    public init(
        name: IdentifierSyntax,
        schemaName: IdentifierSyntax?,
        kind: Kind
    ) {
        self.name = name
        self.schemaName = schemaName
        self.kind = kind
    }
    
    public enum Kind: Equatable {
        case rename(IdentifierSyntax)
        case renameColumn(IdentifierSyntax, IdentifierSyntax)
        case addColumn(ColumnDef)
        case dropColumn(IdentifierSyntax)
    }
    
    public func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}

public struct EmptyStatement: Equatable, Statement {
    public init() {}
    
    public func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}
