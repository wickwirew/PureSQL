//
//  Compiler.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct Compiler {
    public private(set) var schema = Schema()
    public private(set) var queries: [Statement] = []
    public private(set) var migrations: [Statement] = []
    
    private var pragmas = PragmaAnalysis()
    
    public init() {}
    
    @discardableResult
    public mutating func compile(migration: String) -> Diagnostics {
        let (stmts, diagnostics) = compile(
            source: migration,
            validator: IsValidForMigrations(),
            context: "migrations"
        )
        self.migrations.append(contentsOf: stmts)
        return diagnostics
    }
    
    @discardableResult
    public mutating func compile(queries: String) -> Diagnostics {
        let (stmts, diagnostics) = compile(
            source: queries,
            validator: IsValidForQueries(),
            context: "queries"
        )
        self.queries.append(contentsOf: stmts)
        return diagnostics
    }
    
    mutating func compile<Validator>(
        source: String,
        validator: Validator,
        context: String
    ) -> ([Statement], Diagnostics)
        where Validator: StmtSyntaxVisitor, Validator.StmtOutput == Bool
    {
        var stmts: [Statement] = []
        var diagnostics = Diagnostics()
        var validator = validator
        
        for stmtSyntax in Parsers.parse(source: source) {
            if !stmtSyntax.accept(visitor: &validator) {
                diagnostics.add(.illegalStatement(in: context, at: stmtSyntax.range))
            }
            
            guard let (stmt, diags) = stmtSyntax.accept(visitor: &self) else { continue }
            stmts.append(stmt)
            diagnostics.merge(diags)
        }
        
        return (stmts, diagnostics)
    }
    
    /// Just performs type checking.
    private mutating func typeCheck<S: StmtSyntax>(_ stmt: S, isReadOnly: Bool) -> (Statement, Diagnostics) {
        // Calculating the statement signature will type check it.
        // We can just ignore the output
        var typeChecker = StmtTypeChecker(schema: schema, pragmas: pragmas.featherPragmas)
        let signature = typeChecker.signature(for: stmt)
        
        self.schema = typeChecker.schema
        
        let statement = Statement(
            name: nil,
            signature: signature,
            syntax: stmt,
            isReadOnly: isReadOnly,
            sanitizedSource: ""
        )
        
        return (statement, typeChecker.allDiagnostics)
    }
}

extension Compiler: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: true)
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: UpdateStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: DeleteStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> (Statement, Diagnostics)? {
        guard let (innerStmt, diagnostics) = stmt.statement.accept(visitor: &self) else { return nil }
        return (innerStmt.with(name: stmt.name.value), diagnostics)
    }
    
    mutating func visit(_ stmt: PragmaStmt) -> (Statement, Diagnostics)? {
        pragmas.handle(pragma: stmt)
        return (Statement(name: nil, signature: .empty, syntax: stmt, isReadOnly: true, sanitizedSource: ""), Diagnostics())
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> (Statement, Diagnostics)? {
        return nil
    }
}

/// Used to validate whether a statement syntax is valid for use in migrations
struct IsValidForMigrations: StmtSyntaxVisitor {
    func visit(_ stmt: CreateTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: AlterTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: SelectStmtSyntax) -> Bool { false }
    func visit(_ stmt: InsertStmtSyntax) -> Bool { true }
    func visit(_ stmt: UpdateStmtSyntax) -> Bool { true }
    func visit(_ stmt: DeleteStmtSyntax) -> Bool { true }
    func visit(_ stmt: QueryDefinitionStmtSyntax) -> Bool { false }
    func visit(_ stmt: PragmaStmt) -> Bool { true }
    func visit(_ stmt: EmptyStmtSyntax) -> Bool { true }
}

/// Used to validate whether a statement syntax is valid for use in queries
struct IsValidForQueries: StmtSyntaxVisitor {
    func visit(_ stmt: CreateTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: AlterTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: SelectStmtSyntax) -> Bool { true }
    func visit(_ stmt: InsertStmtSyntax) -> Bool { true }
    func visit(_ stmt: UpdateStmtSyntax) -> Bool { true }
    func visit(_ stmt: DeleteStmtSyntax) -> Bool { true }
    func visit(_ stmt: QueryDefinitionStmtSyntax) -> Bool { true }
    func visit(_ stmt: PragmaStmt) -> Bool { true }
    func visit(_ stmt: EmptyStmtSyntax) -> Bool { true }
}

// Mainly used in tests, since they are usually a mix of migrations and queries
struct IsAlwaysValid: StmtSyntaxVisitor {
    func visit(_ stmt: CreateTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: AlterTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: SelectStmtSyntax) -> Bool { true }
    func visit(_ stmt: InsertStmtSyntax) -> Bool { true }
    func visit(_ stmt: UpdateStmtSyntax) -> Bool { true }
    func visit(_ stmt: DeleteStmtSyntax) -> Bool { true }
    func visit(_ stmt: QueryDefinitionStmtSyntax) -> Bool { true }
    func visit(_ stmt: PragmaStmt) -> Bool { true }
    func visit(_ stmt: EmptyStmtSyntax) -> Bool { true }
}
