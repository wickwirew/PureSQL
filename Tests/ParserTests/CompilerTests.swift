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
            CREATE TABLE baz(qux INTEGER PRIMARY KEY, meow TEXT);
            """,
            source: """
            SELECT * FROM baz WHERE qux = ? AND :anus = meow;
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
            schema: try SchemaCompiler().compile(schema).0
        )
        
        return try compiler.compile(stmt)
    }
}
