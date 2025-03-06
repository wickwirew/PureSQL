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
    
    private var pragmas = PragmaAnalyzer()
    
    public init() {}
    
    public mutating func compile(migration: String) -> Diagnostics {
        let (stmts, diagnostics) = compile(
            source: migration,
            validator: IsValidForMigrations(),
            context: "migrations"
        )
        self.migrations.append(contentsOf: stmts)
        return diagnostics
    }
    
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
        var compiler = CompilerWithSource(schema: schema, source: source, pragmas: pragmas)
        
        let (stmtSyntaxes, parsingDiags) = Parsers.parse(source: source)
        diagnostics.merge(parsingDiags)
        
        for stmtSyntax in stmtSyntaxes {
            if !stmtSyntax.accept(visitor: &validator) {
                diagnostics.add(.illegalStatement(in: context, at: stmtSyntax.range))
            }
            
            guard let (stmt, diags) = stmtSyntax.accept(visitor: &compiler) else { continue }
            stmts.append(stmt)
            diagnostics.merge(diags)
        }
        
        schema = compiler.schema
        pragmas = compiler.pragmas
        
        return (stmts, diagnostics)
    }
}

/// Not meant to be exposed beyond this file. The compiler needs
/// to have the source SQL so it can sanitize that. But in the `Compiler`
/// we would have to set it as a property before compilation and clear
/// it after so the `visit` methods would have access to it since they
/// do not take any input.
///
/// Having a basically a wrapper that just holds onto the source
/// and kicks off the compilation seemed cleaner.
fileprivate struct CompilerWithSource {
    var schema: Schema
    let source: String
    var pragmas: PragmaAnalyzer
    
    /// Just performs type checking.
    private mutating func typeCheck<S: StmtSyntax>(
        _ stmt: S,
        isReadOnly: Bool
    ) -> (Statement, Diagnostics) {
        // Calculating the statement signature will type check it.
        // We can just ignore the output
        var typeChecker = StmtTypeChecker(schema: schema, pragmas: pragmas.featherPragmas)
        let (parameters, type) = typeChecker.signature(for: stmt)
        
        var cardinalityInferer = CardinalityInferrer(schema: schema)
        let cardinality = cardinalityInferer.cardinality(for: stmt)
        
        let uniqueParameters = uniquify(parameters: parameters)
            .reduce(into: [:]) { $0[$1.index] = $1 }
        
        var rewriter = Rewriter()
        let (sanitizedSource, sourceSegments) = rewriter.rewrite(stmt, with: uniqueParameters, in: source)
        
        self.schema = typeChecker.schema
        
        let statement = Statement(
            name: nil,
            parameters: uniqueParameters,
            resultColumns: type,
            outputCardinality: cardinality,
            isReadOnly: isReadOnly,
            sanitizedSource: sanitizedSource,
            sourceSegments: sourceSegments,
            syntax: stmt
        )
        
        return (statement, typeChecker.allDiagnostics)
    }
    
    private func uniquify(parameters: [Parameter<Substring?>]) -> [Parameter<String>] {
        var seenNames: Set<String> = []
        var result: [Parameter<String>] = []
        
        func uniquify(_ name: String) -> String {
            if !seenNames.contains(name) {
                return name
            }
            
            // Start at two, so we don't have id and id1, id and id2 makes more sense.
            for i in 2..<Int.max {
                let potential = i == 0 ? name : "\(name)\(i)"
                guard !seenNames.contains(potential) else { continue }
                return potential
            }
            
            fatalError("You might want to take it easy on the parameters")
        }
        
        for parameter in parameters.sorted(by: { $0.index < $1.index }) {
            if let name = parameter.name {
                // Even inferred names can have collisions.
                // Example: bar = ? AND bar = ? would have 2 named bar.
                let name = uniquify(name.description)
                seenNames.insert(name)
                result.append(parameter.with(name: name))
            } else {
                let name = uniquify("value")
                seenNames.insert(name)
                result.append(parameter.with(name: name))
            }
        }
        
        return result
    }
}

extension CompilerWithSource: StmtSyntaxVisitor {
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
        // TODO: Figure out what to do with these
        // TODO: Emit diags from pragmas
        return nil
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> (Statement, Diagnostics)? {
        return nil
    }
    
    mutating func visit(_ stmt: DropTableStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: CreateIndexStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: DropIndexStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: ReindexStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: CreateViewStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: CreateVirtualTableStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
}

/// Used to validate whether a statement syntax is valid for use in migrations
struct IsValidForMigrations: StmtSyntaxVisitor {
    func visit(_ stmt: borrowing CreateTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing AlterTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing SelectStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing InsertStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing UpdateStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DeleteStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing PragmaStmt) -> Bool { true }
    func visit(_ stmt: borrowing EmptyStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DropTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DropIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing ReindexStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing CreateViewStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> Bool { true }
}

/// Used to validate whether a statement syntax is valid for use in queries
struct IsValidForQueries: StmtSyntaxVisitor {
    func visit(_ stmt: borrowing CreateTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing AlterTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing SelectStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing InsertStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing UpdateStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DeleteStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing PragmaStmt) -> Bool { true }
    func visit(_ stmt: borrowing EmptyStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DropTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing DropIndexStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing ReindexStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing CreateViewStmtSyntax) -> Bool { false }
    func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> Bool { false }
}

// Mainly used in tests, since they are usually a mix of migrations and queries
struct IsAlwaysValid: StmtSyntaxVisitor {
    func visit(_ stmt: borrowing CreateTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing AlterTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing SelectStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing InsertStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing UpdateStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DeleteStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing PragmaStmt) -> Bool { true }
    func visit(_ stmt: borrowing EmptyStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DropTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing DropIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing ReindexStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing CreateViewStmtSyntax) -> Bool { true }
    func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> Bool { true }
}
