//
//  ExpressionParserTests.swift
//
//
//  Created by Wes Wickwire on 10/11/24.
//

import XCTest

@testable import Parser

class ExpressionParserTests: XCTestCase {
    private func parserState(_ source: String) throws -> ParserState {
        return try ParserState(Lexer(source: source))
    }
    
    private func execute<P: Parser>(parser: P, source: String) throws -> P.Output {
        var state = try parserState(source)
        return try parser.parse(state: &state)
    }
}

// MARK: - Bind Parameters

extension ExpressionParserTests {
    func testBindParameters() {
        XCTAssertEqual(.unnamed, try execute(parser: BindParameterParser(), source: "?"))
        XCTAssertEqual(.named("variable"), try execute(parser: BindParameterParser(), source: ":variable"))
        XCTAssertEqual(.named("variable"), try execute(parser: BindParameterParser(), source: "@variable"))
        XCTAssertEqual(.named("variable"), try execute(parser: BindParameterParser(), source: "$variable"))
        XCTAssertEqual(.named("variable::another"), try execute(parser: BindParameterParser(), source: "$variable::another"))
        XCTAssertEqual(.named("variable::another(suffix)"), try execute(parser: BindParameterParser(), source: "$variable::another(suffix)"))
    }
}

// MARK: - Operator

extension ExpressionParserTests {
    func testPrefixOperators() {
        XCTAssertEqual(.tilde, try execute(parser: OperatorParser(), source: "~"))
        XCTAssertEqual(.plus, try execute(parser: OperatorParser(), source: "+"))
        XCTAssertEqual(.minus, try execute(parser: OperatorParser(), source: "-"))
    }
    
    func testInfixAndPostfixOperators() {
        XCTAssertEqual(.collate("SIMPLE"), try execute(parser: OperatorParser(), source: "COLLATE SIMPLE"))
        XCTAssertEqual(.concat, try execute(parser: OperatorParser(), source: "||"))
        XCTAssertEqual(.arrow, try execute(parser: OperatorParser(), source: "->"))
        XCTAssertEqual(.doubleArrow, try execute(parser: OperatorParser(), source: "->>"))
        XCTAssertEqual(.multiply, try execute(parser: OperatorParser(), source: "*"))
        XCTAssertEqual(.divide, try execute(parser: OperatorParser(), source: "/"))
        XCTAssertEqual(.mod, try execute(parser: OperatorParser(), source: "%"))
        XCTAssertEqual(.plus, try execute(parser: OperatorParser(), source: "+"))
        XCTAssertEqual(.minus, try execute(parser: OperatorParser(), source: "-"))
        XCTAssertEqual(.bitwiseAnd, try execute(parser: OperatorParser(), source: "&"))
        XCTAssertEqual(.bitwuseOr, try execute(parser: OperatorParser(), source: "|"))
        XCTAssertEqual(.shl, try execute(parser: OperatorParser(), source: "<<"))
        XCTAssertEqual(.shr, try execute(parser: OperatorParser(), source: ">>"))
        XCTAssertEqual(.escape, try execute(parser: OperatorParser(), source: "ESCAPE"))
        XCTAssertEqual(.lt, try execute(parser: OperatorParser(), source: "<"))
        XCTAssertEqual(.gt, try execute(parser: OperatorParser(), source: ">"))
        XCTAssertEqual(.lte, try execute(parser: OperatorParser(), source: "<="))
        XCTAssertEqual(.gte, try execute(parser: OperatorParser(), source: ">="))
        XCTAssertEqual(.eq, try execute(parser: OperatorParser(), source: "="))
        XCTAssertEqual(.eq2, try execute(parser: OperatorParser(), source: "=="))
        XCTAssertEqual(.neq, try execute(parser: OperatorParser(), source: "!="))
        XCTAssertEqual(.neq2, try execute(parser: OperatorParser(), source: "<>"))
        XCTAssertEqual(.`is`, try execute(parser: OperatorParser(), source: "IS"))
        XCTAssertEqual(.isNot, try execute(parser: OperatorParser(), source: "IS NOT"))
        XCTAssertEqual(.isDistinctFrom, try execute(parser: OperatorParser(), source: "IS DISTINCT FROM"))
        XCTAssertEqual(.isNotDistinctFrom, try execute(parser: OperatorParser(), source: "IS NOT DISTINCT FROM"))
        XCTAssertEqual(.between, try execute(parser: OperatorParser(), source: "BETWEEN"))
        XCTAssertEqual(.and, try execute(parser: OperatorParser(), source: "AND"))
        XCTAssertEqual(.`in`, try execute(parser: OperatorParser(), source: "IN"))
        XCTAssertEqual(.match, try execute(parser: OperatorParser(), source: "MATCH"))
        XCTAssertEqual(.like, try execute(parser: OperatorParser(), source: "LIKE"))
        XCTAssertEqual(.regexp, try execute(parser: OperatorParser(), source: "REGEXP"))
        XCTAssertEqual(.glob, try execute(parser: OperatorParser(), source: "GLOB"))
        XCTAssertEqual(.isnull, try execute(parser: OperatorParser(), source: "ISNULL"))
        XCTAssertEqual(.notNull, try execute(parser: OperatorParser(), source: "NOT NULL"))
        XCTAssertEqual(.notnull, try execute(parser: OperatorParser(), source: "NOTNULL"))
        XCTAssertEqual(.not(.between), try execute(parser: OperatorParser(), source: "NOT BETWEEN"))
        XCTAssertEqual(.or, try execute(parser: OperatorParser(), source: "OR"))
    }
}

// MARK: - QualifiedColumn

extension ExpressionParserTests {
    func testQualifiedColumnColumnOnly() throws {
        let result = try XCTUnwrap(execute(parser: QualifiedColumnParser(), source: "foo"))
        XCTAssertEqual(result.schema, nil)
        XCTAssertEqual(result.table, nil)
        XCTAssertEqual(result.column, "foo")
    }
    
    func testQualifiedColumnTableAndColumnOnly() throws {
        let result = try XCTUnwrap(execute(parser: QualifiedColumnParser(), source: "foo.bar"))
        XCTAssertEqual(result.schema, nil)
        XCTAssertEqual(result.table, "foo")
        XCTAssertEqual(result.column, "bar")
    }
    
    func testQualifiedColumnFull() throws {
        let result = try XCTUnwrap(execute(parser: QualifiedColumnParser(), source: "foo.bar.baz"))
        XCTAssertEqual(result.schema, "foo")
        XCTAssertEqual(result.table, "bar")
        XCTAssertEqual(result.column, "baz")
    }
}

// MARK: - QualifiedColumn

extension ExpressionParserTests {
    func expression(_ source: String) throws -> String {
        return try execute(parser: ExprParser(), source: source).description
    }
    
    func testArithmeticExpressions() throws {
        XCTAssertEqual("(1.0 + 2.0)", try expression("1 + 2"))
        XCTAssertEqual("((1.0 + 2.0) + 3.0)", try expression("1 + 2 + 3"))
        XCTAssertEqual("((1.0 * 2.0) + 3.0)", try expression("1 * 2 + 3"))
        XCTAssertEqual("(1.0 + (2.0 * 3.0))", try expression("1 + 2 * 3"))
        XCTAssertEqual("(1.0 + (2.0 / 3.0))", try expression("1 + 2 / 3"))
    }
    
    func testWordExpressions() throws {
        XCTAssertEqual("(foo IS NULL)", try expression("foo IS NULL"))
        XCTAssertEqual("(foo IS DISTINCT FROM NULL)", try expression("foo IS DISTINCT FROM NULL"))
    }
}
