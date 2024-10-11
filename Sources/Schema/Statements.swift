//
//  Statements.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import OrderedCollections

public protocol StatementVisitor {
    associatedtype Output
    func visit(statement: CreateTableStatement) throws -> Output
}

public protocol Statement {
    func accept<V: StatementVisitor>(visitor: V) throws -> V.Output
}

public struct CreateTableStatement: Equatable, Statement {
    public let name: Substring
    public let schemaName: Substring?
    public let isTemporary: Bool
    public let onlyIfExists: Bool
    public let kind: Kind
    public let constraints: [TableConstraint]
    public let options: TableOptions
    
    public enum Kind: Equatable {
        case select(SelectStmt)
        case columns(OrderedDictionary<Substring, ColumnDef>)
    }
    
    public init(
        name: Substring,
        schemaName: Substring?,
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
    
    public func accept<V>(visitor: V) throws -> V.Output where V : StatementVisitor {
        try visitor.visit(statement: self)
    }
}
