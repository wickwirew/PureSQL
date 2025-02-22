//
//  Compiler.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct Compiler {
    public private(set) var schema = Schema()
    public private(set) var statements: [Statement] = []
    public private(set) var migrations: [String] = []
    
    private var diagnostics = Diagnostics()
    private var pragmas = FeatherPragmas()
    
    public init() {}
    
    @discardableResult
    public mutating func compile(migration: String) -> Diagnostics {
        var schemaCompiler = SchemaCompiler(schema: schema)
        let sanitizedMigration = schemaCompiler.compile(migration)
        migrations.append(sanitizedMigration)
        
        schema = schemaCompiler.schema
        pragmas = schemaCompiler.pragmas.featherPragmas
        
        let allDiagnostics = schemaCompiler.allDiagnostics
        diagnostics.merge(allDiagnostics)
        return allDiagnostics
    }
    
    @discardableResult
    public mutating func compile(queries: String) -> ([Statement], Diagnostics) {
        var queryCompiler = QueryCompiler(source: queries, schema: schema, pragmas: pragmas)
        queryCompiler.compile(queries)
        
        statements = queryCompiler.statements
        
        let allDiagnostics = queryCompiler.allDiagnostics
        diagnostics.merge(allDiagnostics)
        return (queryCompiler.statements, allDiagnostics)
    }
}
