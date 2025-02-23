//
//  QueryCompiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import OrderedCollections

/// Compiles and type checks any queries.
public struct QueryCompiler {
    public let source: String
    public let schema: Schema
    private var diagnostics = Diagnostics()
    public private(set) var statements: [Statement] = []
    private(set) var pragmas = PragmaAnalysis()
    
    public init(
        source: String,
        schema: Schema,
        pragmas: FeatherPragmas
    ) {
        self.source = source
        self.schema = schema
        self.pragmas = PragmaAnalysis(featherPragmas: pragmas)
    }
    
    public var allDiagnostics: Diagnostics {
        return diagnostics.merging(pragmas.diagnostics)
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
    
    private mutating func signature<S: StmtSyntax>(of stmt: S) -> Signature {
        var inferrer = TypeChecker(schema: schema)
        let signature = inferrer.signature(for: stmt)
        self.diagnostics.merge(inferrer.diagnostics)
        return signature
    }
}

extension QueryCompiler: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> Statement? {
        diagnostics.add(.illegalStatementInQueries(.create, at: stmt.range))
        return nil
    }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> Statement? {
        diagnostics.add(.illegalStatementInQueries(.alter, at: stmt.range))
        return nil
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: true,
            sanitizedSource: Sanitizer.sanitize(stmt, in: source)
        )
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: false,
            sanitizedSource: Sanitizer.sanitize(stmt, in: source)
        )
    }
    
    mutating func visit(_ stmt: UpdateStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: false,
            sanitizedSource: Sanitizer.sanitize(stmt, in: source)
        )
    }
    
    mutating func visit(_ stmt: DeleteStmtSyntax) -> Statement? {
        return Statement(
            name: nil,
            signature: signature(of: stmt),
            syntax: stmt,
            isReadOnly: false,
            sanitizedSource: Sanitizer.sanitize(stmt, in: source)
        )
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> Statement? {
        guard let inner = stmt.statement.accept(visitor: &self) else {
            diagnostics.add(.init("Query definition was empty", at: stmt.statement.range))
            return nil
        }
        
        return Statement(
            name: stmt.name.value,
            signature: inner.signature,
            syntax: stmt,
            isReadOnly: inner.isReadOnly,
            sanitizedSource: Sanitizer.sanitize(stmt, in: source)
        )
    }
    
    mutating func visit(_ stmt: borrowing PragmaStmt) -> Statement? {
        pragmas.handle(pragma: stmt)
        return nil
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> Statement? {
        return nil
    }
}
