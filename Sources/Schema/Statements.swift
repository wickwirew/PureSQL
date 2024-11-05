//
//  Statements.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import OrderedCollections

public protocol StatementVisitor {
    associatedtype Input
    associatedtype Output
    func visit(statement: CreateTableStatement, with input: Input) throws -> Output
    func visit(statement: AlterTableStatement, with input: Input) throws -> Output
    func visit(statement: EmptyStatement, with input: Input) throws -> Output
}

public protocol Statement {
    func accept<V: StatementVisitor>(visitor: V, with input: V.Input) throws -> V.Output
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
    
    public func accept<V>(visitor: V, with input: V.Input) throws -> V.Output where V : StatementVisitor {
        try visitor.visit(statement: self, with: input)
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
    
    public func accept<V>(visitor: V, with input: V.Input) throws -> V.Output where V : StatementVisitor {
        try visitor.visit(statement: self, with: input)
    }
}

public struct EmptyStatement: Equatable, Statement {
    public init() {}
    
    public func accept<V>(visitor: V, with input: V.Input) throws -> V.Output where V : StatementVisitor {
        try visitor.visit(statement: self, with: input)
    }
}
