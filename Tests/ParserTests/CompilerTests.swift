//
//  CompilerTests.swift
//  SQL
//
//  Created by Wes Wickwire on 11/2/24.
//

import XCTest

@testable import Parser

class CompilerTests: XCTestCase {
    func testMeow() throws {
        let query = try compile(
            schema: """
            CREATE TABLE foo(bar INTEGER);
            CREATE TABLE baz(qux INTEGER, meow TEXT);
            """,
            source: """
            SELECT * FROM foo
            JOIN baz
            WHERE qux == 100
            GROUP BY '';
            """
        )
        
        print(query)
    }
    
    private func compile(schema: String, source: String) throws -> CompiledQuery {
        let parser = SelectStmtParser()
        let stmt = try parser.parse(source)
        
        let compiler = QueryCompiler(
            environment: .init(),
            diagnositics: .init(),
            schema: try SchemaBuilder.build(from: schema)
        )
        
        return try compiler.compile(stmt)
    }
}
