//
//  Compiler.swift
//  Otter
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct Compiler {
    public var schema = Schema()
    private var pragmas = PragmaAnalyzer()

    public init() {}
    
    public mutating func compile(migration: String) -> ([Statement], Diagnostics) {
        compile(
            source: migration,
            validator: IsValidForMigrations(),
            context: "migrations"
        )
    }
    
    public mutating func compile(queries: String) -> ([Statement], Diagnostics) {
        compile(
            source: queries,
            validator: IsValidForQueries(),
            context: "queries"
        )
    }
    
    public mutating func compile(
        query: String,
        named name: String,
        inputType: String?,
        outputType: String?
    ) -> (Statement?, Diagnostics) {
        var (stmts, diagnostics) = compile(
            source: query,
            validator: IsValidForQueries(),
            context: "queries"
        )
        
        guard let stmt = stmts.first else {
            let loc = SourceLocation(range: query.startIndex..<query.endIndex, line: 0, column: 0)
            diagnostics.add(.init("Query has no statements", at: loc))
            return (nil, diagnostics)
        }
        
        let stmtWithDef = stmt.with(
            definition: Definition(
                name: name[...],
                input: inputType?[...],
                output: outputType?[...]
            )
        )
        
        return (stmtWithDef, diagnostics)
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
                diagnostics.add(.illegalStatement(in: context, at: stmtSyntax.location))
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
private struct CompilerWithSource {
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
        var typeChecker = StmtTypeChecker(schema: schema, pragmas: pragmas.otterPragmas)
        let (parameters, type) = typeChecker.signature(for: stmt)
        
        // Note: Make sure to pass env from type checker to make sure all is imported
        var cardinalityInferer = CardinalityInferrer(env: typeChecker.env)
        let cardinality = cardinalityInferer.cardinality(for: stmt)
        
        let uniqueParameters = uniquify(parameters: parameters)
            .sorted { $0.index < $1.index }
        
        var rewriter = Rewriter()
        let (sanitizedSource, sourceSegments) = rewriter.rewrite(stmt, with: uniqueParameters, in: source)
        
        self.schema = typeChecker.schema
        
        let statement = Statement(
            definition: nil,
            parameters: uniqueParameters,
            resultColumns: type,
            outputCardinality: cardinality,
            isReadOnly: isReadOnly,
            sanitizedSource: sanitizedSource,
            sourceSegments: sourceSegments,
            usedTableNames: typeChecker.usedTableNames,
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
        
        let definition = Definition(
            name: stmt.name.value,
            input: stmt.input?.value,
            output: stmt.output?.value
        )
        
        return (innerStmt.with(definition: definition), diagnostics)
    }
    
    mutating func visit(_ stmt: PragmaStmtSyntax) -> (Statement, Diagnostics)? {
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
    
    mutating func visit(_ stmt: DropViewStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: CreateVirtualTableStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: CreateTriggerStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: DropTriggerStmtSyntax) -> (Statement, Diagnostics)? {
        return typeCheck(stmt, isReadOnly: false)
    }
    
    mutating func visit(_ stmt: BeginStmtSyntax) -> (Statement, Diagnostics)? { nil }
    
    mutating func visit(_ stmt: CommitStmtSyntax) -> (Statement, Diagnostics)? { nil }
    
    mutating func visit(_ stmt: RollbackStmtSyntax) -> (Statement, Diagnostics)? { nil }
    
    mutating func visit(_ stmt: SavepointStmtSyntax) -> (Statement, Diagnostics)? { nil }
    
    mutating func visit(_ stmt: ReleaseStmtSyntax) -> (Statement, Diagnostics)? { nil }
    
    mutating func visit(_ stmt: VacuumStmtSyntax) -> (Statement, Diagnostics)? { nil }
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
    func visit(_ stmt: PragmaStmtSyntax) -> Bool { true }
    func visit(_ stmt: EmptyStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: ReindexStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateViewStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropViewStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateVirtualTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateTriggerStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropTriggerStmtSyntax) -> Bool { true }
    func visit(_ stmt: BeginStmtSyntax) -> Bool { false }
    func visit(_ stmt: CommitStmtSyntax) -> Bool { false }
    func visit(_ stmt: RollbackStmtSyntax) -> Bool { false }
    func visit(_ stmt: SavepointStmtSyntax) -> Bool { false }
    func visit(_ stmt: ReleaseStmtSyntax) -> Bool { false }
    func visit(_ stmt: VacuumStmtSyntax) -> Bool { true }
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
    func visit(_ stmt: PragmaStmtSyntax) -> Bool { true }
    func visit(_ stmt: EmptyStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: CreateIndexStmtSyntax) -> Bool { false }
    func visit(_ stmt: DropIndexStmtSyntax) -> Bool { false }
    func visit(_ stmt: ReindexStmtSyntax) -> Bool { false }
    func visit(_ stmt: CreateViewStmtSyntax) -> Bool { false }
    func visit(_ stmt: DropViewStmtSyntax) -> Bool { false }
    func visit(_ stmt: CreateVirtualTableStmtSyntax) -> Bool { false }
    func visit(_ stmt: CreateTriggerStmtSyntax) -> Bool { false }
    func visit(_ stmt: DropTriggerStmtSyntax) -> Bool { false }
    func visit(_ stmt: BeginStmtSyntax) -> Bool { false }
    func visit(_ stmt: CommitStmtSyntax) -> Bool { false }
    func visit(_ stmt: RollbackStmtSyntax) -> Bool { false }
    func visit(_ stmt: SavepointStmtSyntax) -> Bool { false }
    func visit(_ stmt: ReleaseStmtSyntax) -> Bool { false }
    func visit(_ stmt: VacuumStmtSyntax) -> Bool { false }
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
    func visit(_ stmt: PragmaStmtSyntax) -> Bool { true }
    func visit(_ stmt: EmptyStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropIndexStmtSyntax) -> Bool { true }
    func visit(_ stmt: ReindexStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateViewStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropViewStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateVirtualTableStmtSyntax) -> Bool { true }
    func visit(_ stmt: CreateTriggerStmtSyntax) -> Bool { true }
    func visit(_ stmt: DropTriggerStmtSyntax) -> Bool { true }
    func visit(_ stmt: BeginStmtSyntax) -> Bool { true }
    func visit(_ stmt: CommitStmtSyntax) -> Bool { true }
    func visit(_ stmt: RollbackStmtSyntax) -> Bool { true }
    func visit(_ stmt: SavepointStmtSyntax) -> Bool { true }
    func visit(_ stmt: ReleaseStmtSyntax) -> Bool { true }
    func visit(_ stmt: VacuumStmtSyntax) -> Bool { true }
}
