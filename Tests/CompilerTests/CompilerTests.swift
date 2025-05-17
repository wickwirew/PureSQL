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
    
    func testDropTable() throws {
        try checkQueries(compile: "CompileDropTable")
    }
    
    func testView() throws {
        try checkSchema(compile: "CompileView", prefix: "CHECK-SCHEMA")
        try checkQueries(compile: "CompileView", prefix: "CHECK-QUERIES")
    }
    
    func testFTS5() throws {
        try checkSchema(compile: "CompileFTS5", prefix: "CHECK-SCHEMA")
        try checkQueries(compile: "CompileFTS5", prefix: "CHECK-QUERIES")
    }
    
    func testSpecialNames() throws {
        try checkQueries(compile: "CompileSpecialNames")
    }
    
    func testOutputCountInference() throws {
        try check(
            sqlFile: "CompileIsSingleResult",
            parse: { contents in
                var compiler = Compiler()
                _ = compiler.compile(queries: contents)
                return compiler.queries
                    .filter{ !($0.syntax is CreateTableStmtSyntax) }
                    .map { $0.outputCardinality.rawValue.uppercased() }
            }
        )
    }
}

struct CheckSignature: Checkable {
    let parameters: [Parameter<String>]
    let outputChunks: [Chunk]
    let tables: [Substring]
    
    struct Chunk {
        let output: [String]
        let outputTable: Substring?
    }
    
    init(_ statement: Statement) {
        self.parameters = statement.parameters
        self.outputChunks = statement.resultColumns.chunks.map { chunk in
            Chunk(output: chunk.columns.map{ "\($0) \($1)" }, outputTable: chunk.table)
        }
        self.tables = statement.usedTableNames.sorted()
    }
    
    var typeName: String {
        return "Signature"
    }
}

func checkSchema(
    compile sqlFile: String,
    prefix: String = "CHECK",
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try checkWithErrors(
        compile: sqlFile,
        parse: { contents in
            var compiler = Compiler()
            let (_, diags) = compiler.compile(
                source: contents,
                validator: IsAlwaysValid(),
                context: "tests"
            )
            return (Array(compiler.schema.values), diags)
        },
        prefix: prefix,
        dump: dump,
        file: file,
        line: line
    )
}

func checkQueries(
    compile sqlFile: String,
    prefix: String = "CHECK",
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
            
            var isQuery = IsValidForQueries()
            return (
                stmts
                    .filter{ $0.syntax.accept(visitor: &isQuery) }
                    .map { CheckSignature($0) },
                diags
            )
        },
        prefix: prefix,
        dump: dump,
        file: file,
        line: line
    )
}

func checkWithErrors<Output>(
    compile sqlFile: String,
    parse: (String) -> ([Output], Diagnostics),
    prefix: String = "CHECK",
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
        prefix: prefix,
        dump: dump,
        file: file,
        line: line
    )

    try check(
        sqlFile: sqlFile,
        parse: { _ in diagnostics.map(\.message) },
        prefix: "CHECK-ERROR",
        dump: dump,
        file: file,
        line: line
    )
}
