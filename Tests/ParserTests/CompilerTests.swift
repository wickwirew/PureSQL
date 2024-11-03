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
            SELECT *, bar + 1 * :meow FROM foo
            INNER JOIN baz;
            """
        )
        
        print(query)
    }
    
    private func compile(schema: String, source: String) throws -> CompiledQuery {
        let parser = SelectStmtParser()
        let stmt = try parser.parse(source)
        
        var compiler = QueryCompiler(
            environment: .init(),
            diagnositics: .init(),
            schema: try SchemaBuilder.build(from: schema)
        )
        
        return try compiler.compile(stmt)
    }
}
