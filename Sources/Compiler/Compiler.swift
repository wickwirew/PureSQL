//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import OrderedCollections

public struct Compiler {
    public private(set) var schema: Schema
    public private(set) var diagnostics = Diagnostics()
    public private(set) var statements: [Statement] = []
    
    public init(
        schema: Schema = Schema(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    public mutating func compile(_ source: String) {
        compile(Parsers.parse(source: source))
    }
    
    mutating func compile(_ stmts: [StmtSyntax]) {
        for stmt in stmts {
            guard let stmt = stmt.accept(visitor: &self) else { continue }
            statements.append(stmt)
        }
    }
}

extension Compiler: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> Statement? {
        let tablePrimaryKeyConstraints = stmt.constraints
            .compactMap { constraint -> [Substring]? in
                guard case let .primaryKey(columns, _) = constraint.kind else { return nil }
                return columns.compactMap(\.columnName?.value)
            }
            .flatMap(\.self)
        
        switch stmt.kind {
        case let .select(selectStmt):
            let signature = signature(of: selectStmt)
            
            guard case let .row(.named(columns)) = signature.output else {
                assertionFailure("Create table did not have named columns")
                return Statement(name: nil, signature: .empty, syntax: stmt, isReadOnly: false)
            }
            
            schema[stmt.name.value] = Table(
                name: stmt.name.value,
                columns: columns,
                primaryKey: tablePrimaryKeyConstraints
            )
            return Statement(name: nil, signature: signature, syntax: stmt, isReadOnly: false)
        case let .columns(columns):
            // If there were no primary keys defined in the table constraints
            // check if any columns have the PRIMARY KEY constraint.
            let primaryKey: [Substring] = if tablePrimaryKeyConstraints.isEmpty {
                columns.values
                    .filter{ $0.constraints.contains(where: \.isPkConstraint) }
                    .map(\.name.value)
            } else {
                tablePrimaryKeyConstraints
            }
            
            schema[stmt.name.value] = Table(
                name: stmt.name.value,
                columns: columns.reduce(into: [:]) {
                    $0[$1.value.name.value] = typeFor(column: $1.value)
                },
                primaryKey: primaryKey
            )
            return Statement(name: nil, signature: .empty, syntax: stmt, isReadOnly: false)
        }
    }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> Statement? {
        guard var table = schema[stmt.name.value] else {
            diagnostics.add(.init("Table '\(stmt.name)' does not exist", at: stmt.name.range))
            return Statement(name: nil, signature: .empty, syntax: stmt, isReadOnly: false)
        }
        
        switch stmt.kind {
        case let .rename(newName):
            schema[stmt.name.value] = nil
            schema[newName.value] = table
        case let .renameColumn(oldName, newName):
            table.columns = table.columns.reduce(into: [:]) { $0[$1.key == oldName.value ? newName.value : $1.key] = $1.value }
        case let .addColumn(column):
            table.columns[column.name.value] = typeFor(column: column)
        case let .dropColumn(column):
            table.columns[column.value] = nil
        }
        
        schema[stmt.name.value] = table
        return Statement(
            name: nil,
            signature: .empty,
            syntax: stmt,
            isReadOnly: false
        )
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: true
        )
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: false
        )
    }
    
    mutating func visit(_ stmt: UpdateStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: false
        )
    }
    
    mutating func visit(_ stmt: DeleteStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: false
        )
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> Statement? {
        guard let inner = stmt.statement.accept(visitor: &self) else {
            // TODO: Show Error? Really dont know if this can happen.
            return nil
        }
        
        return Statement(name: stmt.name.value, signature: inner.signature, syntax: stmt, isReadOnly: inner.isReadOnly)
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> Statement? {
        return nil
    }
    
    private func typeFor(column: borrowing ColumnDefSyntax) -> Type {
        // Technically you can have a NULL primary key but I don't
        // think people actually do that...
        let isNotNullable = column.constraints
            .contains { $0.isPkConstraint || $0.isNotNullConstraint }
        
        if isNotNullable {
            return .nominal(column.type.name.value)
        } else {
            return .optional(.nominal(column.type.name.value))
        }
    }
    
    private mutating func signature<S: StmtSyntax>(of stmt: S) -> Signature {
        var inferrer = TypeInferrer(schema: schema)
        let signature = inferrer.signature(for: stmt)
        self.diagnostics.merge(inferrer.diagnostics)
        return signature
    }
}
