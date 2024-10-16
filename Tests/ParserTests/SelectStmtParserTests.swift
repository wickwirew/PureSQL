//
//  SelectStmtParserTests.swift
//
//
//  Created by Wes Wickwire on 10/15/24.
//

import XCTest
import Schema

@testable import Parser

class SelectStmtParserTests: XCTestCase {
    private func parserState(_ source: String) throws -> ParserState {
        return try ParserState(Lexer(source: source))
    }
    
    private func execute<P: Parser>(parser: P, source: String) throws -> P.Output {
        var state = try parserState(source)
        return try parser.parse(state: &state)
    }
}

extension SelectStmtParserTests {
    func testSimpleSelect() throws {
        let stmt = try execute(parser: SelectStmtParser(), source: "SELECT * FROM foo")
        
        let expected = SelectStmt(
            select: SelectCore.Select(
                distinct: false,
                columns: [.all(table: nil)],
                from: SelectCore.From(table: "foo"),
                where: nil,
                groupBy: nil,
                windows: []
            )
        )
        
        XCTAssertEqual(stmt, expected)
    }
}
