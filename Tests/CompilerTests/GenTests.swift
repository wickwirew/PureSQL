//
//  GenTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/23/25.
//

import Testing
import Foundation

@testable import Compiler

@Suite
struct GenTests {
    @Test(arguments: [
        ("Swift", GenerationOptions(databaseName: "DB")),
        ("SwiftWithPattern", GenerationOptions(databaseName: "DB", tableNamePattern: "%@Record")),
    ]) func generation(args: (outputFile: String, options: GenerationOptions)) throws {
        var compiler = Compiler()
        let migrations = try compiler.compile(migration: load(file: "Migrations"))
        let queries = try compiler.compile(queries: load(file: "Queries"))
        
        for diagnostics in migrations.1 {
            Issue.record(diagnostics)
        }
        
        for diagnostics in queries.1 {
            Issue.record(diagnostics)
        }
        
        guard migrations.1.isEmpty && queries.1.isEmpty else { return }
        
        let language = SwiftLanguage(options: args.options)
        let rawOutput = try language.generate(
            migrations: [migrations.0.map(\.sanitizedSource).joined(separator: "\n\n")],
            queries: [("Queries", queries.0)],
            schema: compiler.schema
        )

        let expected = try load(file: args.outputFile, ext: "output")
            .split(separator: "\n")
            .filter{ !$0.isEmpty }
        
        let output = rawOutput
            .split(separator: "\n")
            .filter{ !$0.isEmpty }
        
        for (expected, output) in zip(expected, output) {
            #expect(expected == output)
            
            if expected != output {
                break
            }
        }
        
        #expect(output.count == expected.count)
    }
    
    private func load(file: String, ext: String = "sql") throws -> String {
        guard let url = Bundle.module.url(forResource: file, withExtension: ext) else {
            struct NotFound: Error {}
            throw NotFound()
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
