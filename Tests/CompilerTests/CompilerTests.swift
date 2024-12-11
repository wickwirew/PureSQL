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
            return compiler.queries
        },
        prefix: "CHECK",
        dump: dump,
        file: file,
        line: line
    )
    
    guard !diagnostics.isEmpty else { return }
    
    try check(
        sqlFile: sqlFile,
        parse: { _ in diagnostics.map(\.message) },
        prefix: "CHECK-ERROR",
        dump: dump,
        file: file,
        line: line
    )
}
