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
//
// Note: The tests are ordered to match the flow chart here:
// https://www.sqlite.org/lang_expr.html

extension ExpressionParserTests {
    /// Just a little helper that returns the description of the parsed expr. Creating the
    /// results manually would be insane and hard to read. This is for my sanity.
    func expression(_ source: String) throws -> String {
        return try execute(parser: ExprParser(), source: source).description
    }
    
    func testLiteralValueExpressions() throws {
        XCTAssertEqual("1.0", try expression("1"))
        XCTAssertEqual("255.0", try expression("0xFF"))
        XCTAssertEqual("1.0", try expression("100e-2"))
        XCTAssertEqual("'foo'", try expression("'foo'"))
        XCTAssertEqual("NULL", try expression("NULL"))
        XCTAssertEqual("TRUE", try expression("TRUE"))
        XCTAssertEqual("FALSE", try expression("FALSE"))
        XCTAssertEqual("CURRENT_TIME", try expression("CURRENT_TIME"))
        XCTAssertEqual("CURRENT_DATE", try expression("CURRENT_DATE"))
        XCTAssertEqual("CURRENT_TIMESTAMP", try expression("CURRENT_TIMESTAMP"))
    }
    
    func testBindParameterExpressions() throws {
        XCTAssertEqual(":foo", try expression(":foo"))
    }
    
    func testColumnNameExpressions() throws {
        XCTAssertEqual("foo", try expression("foo"))
        XCTAssertEqual("foo.bar", try expression("foo.bar"))
        XCTAssertEqual("foo.bar.baz", try expression("foo.bar.baz"))
    }
    
    func testPrefixExpressions() throws {
        XCTAssertEqual("(~1.0)", try expression("~1"))
        XCTAssertEqual("(+1.0)", try expression("+1"))
        XCTAssertEqual("(-1.0)", try expression("-1"))
    }
    
    func testBinaryExpressions() throws {
        XCTAssertEqual("(1.0 + 2.0)", try expression("1 + 2"))
        XCTAssertEqual("((1.0 + 2.0) + 3.0)", try expression("1 + 2 + 3"))
        XCTAssertEqual("((1.0 * 2.0) + 3.0)", try expression("1 * 2 + 3"))
        XCTAssertEqual("(1.0 + (2.0 * 3.0))", try expression("1 + 2 * 3"))
        XCTAssertEqual("(1.0 + (2.0 / 3.0))", try expression("1 + 2 / 3"))
        XCTAssertEqual("(1.0 + (-2.0))", try expression("1 +-2"))
        XCTAssertEqual("((1.0 + 2.0))", try expression("(1 + 2)"))
        XCTAssertEqual("(((1.0 + 2.0)) * 3.0)", try expression("(1 + 2) * 3"))
    }
    
    func testFunctionExpressions() throws {
        XCTAssertEqual("foo(1.0)", try expression("foo(1)"))
        XCTAssertEqual("foo(1.0, (2.0 + 3.0))", try expression("foo(1, 2 + 3)"))
        XCTAssertEqual("foo(bar.baz)", try expression("foo(bar.baz)"))
    }
    
    func testCastExpressions() throws {
        XCTAssertEqual("CAST(foo AS TEXT)", try expression("CAST(foo AS TEXT)"))
    }
    
    func testCollateExpressions() throws {
        XCTAssertEqual("('foo' COLLATE NOCASE)", try expression("'foo' COLLATE NOCASE"))
    }
    
    func testTextMatchExpressions() throws {
        XCTAssertEqual("(foo NOT LIKE 'bar')", try expression("foo NOT LIKE 'bar'"))
        XCTAssertEqual("(foo LIKE 'bar')", try expression("foo LIKE 'bar'"))
        XCTAssertEqual("(foo LIKE ('bar' ESCAPE '\\'))", try expression("foo LIKE 'bar' ESCAPE '\\'"))
        XCTAssertEqual("(foo NOT GLOB 'bar')", try expression("foo NOT GLOB 'bar'"))
        XCTAssertEqual("(foo GLOB 'bar')", try expression("foo GLOB 'bar'"))
        XCTAssertEqual("(foo NOT REGEXP 'bar')", try expression("foo NOT REGEXP 'bar'"))
        XCTAssertEqual("(foo REGEXP 'bar')", try expression("foo REGEXP 'bar'"))
        XCTAssertEqual("(foo NOT MATCH 'bar')", try expression("foo NOT MATCH 'bar'"))
        XCTAssertEqual("(foo MATCH 'bar')", try expression("foo MATCH 'bar'"))
    }
    
    func testPostfixExpressions() throws {
        XCTAssertEqual("(foo ISNULL)", try expression("foo ISNULL"))
        XCTAssertEqual("(foo NOTNULL)", try expression("foo NOTNULL"))
        XCTAssertEqual("(foo NOT NULL)", try expression("foo NOT NULL"))
    }
    
    func testIsExpressions() throws {
        XCTAssertEqual("(foo IS DISTINCT FROM 1.0)", try expression("foo IS DISTINCT FROM 1"))
        XCTAssertEqual("(foo IS NOT DISTINCT FROM 1.0)", try expression("foo IS NOT DISTINCT FROM 1"))
        XCTAssertEqual("(foo IS NOT 1.0)", try expression("foo IS NOT 1"))
        XCTAssertEqual("(foo IS 1.0)", try expression("foo IS 1"))
    }
    
    func testBetweenExpressions() throws {
        XCTAssertEqual("(foo BETWEEN 1.0 AND 2.0)", try expression("foo BETWEEN 1 AND 2"))
        XCTAssertEqual("(foo BETWEEN (1.0 + 2.0) AND (2.0 * 5.0))", try expression("foo BETWEEN 1 + 2 AND 2 * 5"))
        XCTAssertEqual("(foo NOT BETWEEN 1.0 AND 2.0)", try expression("foo NOT BETWEEN 1 AND 2"))
    }
    
    func testInExpressions() throws {
        XCTAssertEqual("(foo IN (1.0, 2.0, 3.0))", try expression("foo IN (1, 2, 3)"))
        XCTAssertEqual("(foo NOT IN (1.0, 2.0, 3.0))", try expression("foo NOT IN (1, 2, 3)"))
        XCTAssertEqual("(foo IN foo.baz(1.0))", try expression("foo IN foo.baz(1)"))
        XCTAssertEqual("(foo IN foo.baz)", try expression("foo IN foo.baz"))
    }
    
    func testCaseWhenThenExpressions() throws {
        XCTAssertEqual(
            "CASE foo WHEN 1.0 THEN 'one' WHEN 2.0 THEN 'two' WHEN 3.0 THEN 'three' END",
            try expression("CASE foo WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' END")
        )
        
        XCTAssertEqual(
            "CASE WHEN 1.0 THEN 'one' WHEN 2.0 THEN 'two' WHEN 3.0 THEN 'three' END",
            try expression("CASE WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' END")
        )
        
        XCTAssertEqual(
            "CASE WHEN 1.0 THEN 'one' WHEN 2.0 THEN 'two' WHEN 3.0 THEN 'three' ELSE 'meh' END",
            try expression("CASE WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' ELSE 'meh' END")
        )
    }
    
    func testWordExpressions() throws {
        XCTAssertEqual("(foo IS NULL)", try expression("foo IS NULL"))
        XCTAssertEqual("(foo IS DISTINCT FROM NULL)", try expression("foo IS DISTINCT FROM NULL"))
        XCTAssertEqual("(foo BETWEEN 1.0 AND 2.0)", try expression("foo BETWEEN 1 AND 2"))
        XCTAssertEqual("(foo BETWEEN (1.0 + 2.0) AND (2.0 * 5.0))", try expression("foo BETWEEN 1 + 2 AND 2 * 5"))
        XCTAssertEqual("(foo NOT BETWEEN 1.0 AND 2.0)", try expression("foo NOT BETWEEN 1 AND 2"))
    }
}
