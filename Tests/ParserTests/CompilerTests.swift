//
//  CompilerTests.swift
//  SQL
//
//  Created by Wes Wickwire on 11/2/24.
//

import XCTest
import Schema


@testable import Parser

class CompilerTests: XCTestCase {
    func testCheckSimpleSelects() throws {
        try checkQueries(sqlFile: "SimpleSelects")
    }
    
    func testSelectWithJoins() throws {
        try checkQueries(sqlFile: "SelectWithJoins")
    }
}

func checkQueries(
    sqlFile: String,
    prefix: String = "CHECK",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard let url = Bundle.module.url(forResource: sqlFile, withExtension: "sql") else {
        XCTFail("Could not find SQL file named \(sqlFile)", file: file, line: line)
        return
    }
    
    let contents = try String(contentsOf: url)
    
    var state = try ParserState(Lexer(source: contents))
    let parser = StmtParser()
    var output: [Statement] = []
    
    let schemaCompiler = SchemaCompiler()
    
    while state.current.kind != .eof {
        try output.append(parser.parse(state: &state))
    }
    
    let schema = schemaCompiler.compile(output).0
    
    var checkTexts: [String] = []
    
    for stmt in output {
        switch stmt {
        case let stmt as SelectStmt:
            var compiler = QueryCompiler(schema: schema)
            let query = try compiler.compile(stmt)
            guard case let .row(.named(columns)) = query.output else { fatalError() }
            let values = query.inputs.map { "IN \($0)" } + columns.map { "OUT \($0.key): \($0.value)" }
            checkTexts.append(values.joined(separator: "\n"))
            checkTexts.append(contentsOf: compiler.diagnositics.diagnostics.map { "ERROR \($0.message)" })
        default:
            break
        }
    }
    
    try check(
        contents: contents,
        equalTo: checkTexts.joined(separator: "\n"),
        prefix: prefix,
        file: file,
        line: line
    )
}
