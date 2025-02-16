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
        try check(compile: "SimpleSelects")
    }

    func testSelectWithJoins() throws {
        try check(compile: "SelectWithJoins")
    }

    func testInsert() throws {
        try check(compile: "Insert")
    }
    
    func testOutputCountInference() throws {
        try check(
            sqlFile: "IsSingleResult",
            parse: { contents in
                var compiler = Compiler()
                compiler.compile(contents)
                return compiler.statements
                    .filter{ !($0.syntax is CreateTableStmtSyntax) }
                    .map { $0.signature.outputIsSingleElement ? "SINGLE" : "MANY" }
            }
        )
    }
}

func check(
    compile sqlFile: String,
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    var diagnostics: [Diagnostic] = []

    try check(
        sqlFile: sqlFile,
        parse: { contents in
            var compiler = Compiler()
            compiler.compile(contents)
            diagnostics = compiler.diagnostics.diagnostics
            return compiler.statements.map(\.signature).filter{ !$0.isEmpty }
        },
        prefix: "CHECK",
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
