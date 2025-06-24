//
//  GenTests.swift
//  Otter
//
//  Created by Wes Wickwire on 6/23/25.
//

import Testing
import Foundation

@testable import Compiler

@Suite
struct GenTests {
    @Test func generation() throws {
        var compiler = Compiler()
        let migrations = try compiler.compile(migration: load(file: "Migrations"))
        let queries = try compiler.compile(queries: load(file: "Queries"))
        
        let language = SwiftLanguage(options: GenerationOptions())
        let rawOutput = try language.generate(
            migrations: migrations.0.map(\.sanitizedSource),
            queries: [("Queries", queries.0)],
            schema: compiler.schema
        )
        
        print(rawOutput)
        let expected = try load(file: "Swift", ext: "output")
            .split(separator: "\n")
            .filter{ !$0.isEmpty }
        
        let output = rawOutput
            .split(separator: "\n")
            .filter{ !$0.isEmpty }
        
        for (expected, output) in zip(expected, output) {
            #expect(expected == output)
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
