//
//  CompilerTests.swift
//  SQL
//
//  Created by Wes Wickwire on 11/2/24.
//

import XCTest

@testable import Compiler

class CompilerTests: XCTestCase {
    func testCheckSimpleSelects() throws {
        try checkQueries(compile: "SimpleSelects")
    }

    func testSelectWithJoins() throws {
        try checkQueries(compile: "SelectWithJoins")
    }

    func testInsert() throws {
        try checkQueries(compile: "Insert")
    }
    
    func testUpdate() throws {
        try checkQueries(compile: "Update")
    }
    
    func testDelete() throws {
        try checkQueries(compile: "Delete")
    }
    
    func testCreateTable() throws {
        try checkSchema(compile: "CreateTable2", dump: true)
    }
    
    func testOutputCountInference() throws {
        try check(
            sqlFile: "IsSingleResult",
            parse: { contents in
                var schemaCompiler = SchemaCompiler()
                schemaCompiler.compile(contents)
                
                var compiler = QueryCompiler(schema: schemaCompiler.schema)
                compiler.compile(contents)
                return compiler.statements
                    .filter{ !($0.syntax is CreateTableStmtSyntax) }
                    .map { $0.signature.outputCardinality.rawValue.uppercased() }
            }
        )
    }
}
func checkSchema(
    compile sqlFile: String,
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try checkWithErrors(
        compile: sqlFile,
        parse: { contents in
            var schemaCompiler = SchemaCompiler()
            schemaCompiler.compile(contents)
            return (Array(schemaCompiler.schema.values), schemaCompiler.diagnostics)
        },
        dump: dump,
        file: file,
        line: line
    )
}

func checkQueries(
    compile sqlFile: String,
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try checkWithErrors(
        compile: sqlFile,
        parse: { contents in
            var schemaCompiler = SchemaCompiler()
            schemaCompiler.compile(contents)
            
            var compiler = QueryCompiler(schema: schemaCompiler.schema)
            compiler.compile(contents)

            return (
                compiler.statements.map(\.signature).filter{ !$0.isEmpty },
                compiler.diagnostics
            )
        },
        dump: dump,
        file: file,
        line: line
    )
}

func checkWithErrors<Output>(
    compile sqlFile: String,
    parse: (String) -> ([Output], Diagnostics),
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    var diagnostics: [Diagnostic] = []

    try check(
        sqlFile: sqlFile,
        parse: { contents in
            let (output, diags) = parse(contents)
            diagnostics.append(contentsOf: diags.elements)
            return output
        },
        prefix: "CHECK",
        dump: dump,
        file: file,
        line: line
    )

    try check(
        sqlFile: sqlFile,
        parse: { _ in diagnostics.map(\.message)
            // Ignore illegal in migrations/queries since its nice to mix them in tests
            .filter { !$0.contains("in migrations") && !$0.contains("in queries") } },
        prefix: "CHECK-ERROR",
        dump: dump,
        file: file,
        line: line
    )
}
