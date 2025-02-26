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
        try checkQueries(compile: "CompileSimpleSelects", dump: true)
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
                    .map { $0.outputCardinality.rawValue.uppercased() }
            }
        )
    }
}

struct CheckSignature: Checkable {
    let parameters: [Parameter<String>]
    let output: Type?
    
    init(_ statement: Statement) {
        self.parameters = statement.parameters.values.sorted(by: { $0.index < $1.index })
        self.output = statement.output
    }
    
    var typeName: String {
        return "Signature"
    }
    
    var customMirror: Mirror {
        // Helps the CHECK statements in the tests since the `Type`
        // structure is fairly complex and has lots of nesting.
        let outputTypes: [String] = if case let .row(.named(columns)) = output {
            columns.elements.map { "\($0) \($1)" }
        } else {
            []
        }
        
        return Mirror(
            self,
            children: [
                "parameters": parameters,
                "output": outputTypes,
            ]
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
            let (_, diags) = compiler.compile(
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
                stmts.map { CheckSignature($0) }.filter{ !$0.parameters.isEmpty || $0.output != nil },
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
        parse: { _ in diagnostics.map(\.message) },
        prefix: "CHECK-ERROR",
        dump: dump,
        file: file,
        line: line
    )
}
