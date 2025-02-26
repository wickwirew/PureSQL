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
        try checkQueries(compile: "CompileSimpleSelects")
    }

    func testSelectWithJoins() throws {
        try checkQueries(compile: "CompileSelectWithJoins")
    }

    func testInsert() throws {
        try checkQueries(compile: "CompileInsert")
    }
    
    func testUpdate() throws {
        try checkQueries(compile: "CompileUpdate")
    }
    
    func testDelete() throws {
        try checkQueries(compile: "CompileDelete")
    }
    
    func testCreateTable() throws {
        try checkSchema(compile: "CompileCreateTable")
    }
    
    func testOutputCountInference() throws {
        try check(
            sqlFile: "CompileIsSingleResult",
            parse: { contents in
                var compiler = Compiler()
                compiler.compile(queries: contents)
                return compiler.queries
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
            var compiler = Compiler()
            let (stmts, diags) = compiler.compile(
                source: contents,
                validator: IsAlwaysValid(),
                context: "tests"
            )
            return (Array(compiler.schema.values), diags)
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
            var compiler = Compiler()
            let (stmts, diags) = compiler.compile(
                source: contents,
                validator: IsAlwaysValid(),
                context: "tests"
            )
            return (
                stmts.map(\.signature).filter{ !$0.isEmpty },
                diags
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
