//
//  TypeCheckerTests.swift
//
//
//  Created by Wes Wickwire on 10/21/24.
//

import Foundation
import XCTest

@testable import Compiler

class TypeCheckerTests: XCTestCase {
    struct Result {
        let parameters: [Parameter<Substring?>]
        let type: Type
        let diagnostics: Diagnostics
    }
    
    func testTypeCheckLiterals() {
        XCTAssertEqual(.integer, try check("1"))
        XCTAssertEqual(.real, try check("1.0"))
        XCTAssertEqual(.text, try check("'hi'"))
    }
    
    func testTypeCheckAddition() {
        XCTAssertEqual(.integer, try check("1 + 1"))
        XCTAssertEqual(.real, try check("1.0 + 1.0"))
        XCTAssertEqual(.real, try check("1 + 1.0"))
        XCTAssertEqual(.real, try check("1.0 + 1"))
        XCTAssertEqual(.integer, try check("-1 + -1"))
    }
    
    func testTypeCheckComparison() {
        XCTAssertEqual(.integer, try check("1 + 1 > 1"))
        XCTAssertEqual(.integer, try check("1 >= 1 - 1 * 2"))
        XCTAssertEqual(.integer, try check("1 > 1"))
        XCTAssertEqual(.integer, try check("1 < 1"))
        XCTAssertEqual(.integer, try check("1 <= 1"))
        XCTAssertEqual(.integer, try check("1 != 1 - 1 * 2"))
        XCTAssertEqual(.integer, try check("1 <> 1"))
        XCTAssertEqual(.integer, try check("1 = 1"))
        XCTAssertEqual(.integer, try check("1 == 1"))
    }
    
    func testTypeCheckBind() throws {
        let result = try result(for: ":foo + 1 > :bar + 2.0 AND :baz")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.real, type(for: "foo", in: result))
        XCTAssertEqual(.real, type(for: "bar", in: result))
        XCTAssertEqual(.integer, type(for: "baz", in: result))
    }
    
    func testTypeCheckBind2() throws {
        let result = try result(for: "1.0 + 2 * 3 * 4 * ?")
        XCTAssertEqual(.real, result.type)
        XCTAssertEqual(.real, type(for: 1, in: result))
    }
    
    func testNames() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER);
        """)
        
        let result = try result(for: "bar = ?", in: scope)
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.optional(.integer), type(for: 1, in: result))
        XCTAssertEqual("bar", name(for: 1, in: result))
    }
    
    func testUnnamedBindParamNameNotRightNextToColumn() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER NOT NULL);
        """)
        
        let result = try result(for: "bar + 1 = ?", in: scope)
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.integer, type(for: 1, in: result))
        XCTAssertEqual("bar", name(for: 1, in: result))
    }
    
    func testUnnamedBindParamNameNotRightNextToColumn2() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER NOT NULL);
        """)
        
        let result = try result(for: "1 + bar = ?", in: scope)
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.integer, type(for: 1, in: result))
        XCTAssertEqual("bar", name(for: 1, in: result))
    }
    
    func testTypeCheckBetween() throws {
        let result = try result(for: "1 BETWEEN 1 AND ?")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.integer, type(for: 1, in: result))
    }
    
    func testTypeFunction() throws {
        try XCTAssertEqual(.integer, result(for: "max(1)").type)
        try XCTAssertEqual(.real, result(for: "max(1.0, 1)").type)
        try XCTAssertEqual(.real, result(for: "max(1, 1.0)").type)
        try XCTAssertEqual(.real, result(for: "max(1, 1, 1.0)").type)
        try XCTAssertEqual(.real, result(for: "max(1, 1, 1.0, 1)").type)
        try XCTAssertEqual(.real, result(for: "max(1, 1, 1, 1.0)").type)
    }
    
    func testTypeFunctionComplex() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar REAL NOT NULL);
        """)
        
        let result = try result(for: "max(1, 1, bar + 1, 1)", in: scope)
        XCTAssertEqual(.real, result.type)
    }
    
    func testTypeFunctionInputGetBound() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar REAL NOT NULL);
        """)
        
        let result = try result(for: "max(1, 1, bar + ?, 1)", in: scope)
        XCTAssertEqual(.real, result.type)
        XCTAssertEqual(.real, type(for: 1, in: result))
    }
    
    func testErrors() throws {
        let result = try result(for: "'a' + 'b'")
        XCTAssertEqual(.text, result.type)
    }
    
    func testCast() throws {
        let result = try result(for: "CAST(1 AS TEXT)")
        XCTAssertEqual(.text, result.type)
    }
    
    func testCaseWhenThenWithCaseExpr() throws {
        let result = try result(for: "CASE 1 WHEN ? THEN '' WHEN 3 THEN '' ELSE '' END")
        XCTAssertEqual(.text, result.type)
        XCTAssertEqual(.integer, type(for: 1, in: result))
    }
    
    func testCaseWhenThenWithNoCaseExpr() throws {
        let result = try result(for: "CASE 1 WHEN ? + 1 THEN '' WHEN 3.0 THEN '' ELSE '' END")
        XCTAssertEqual(.text, result.type)
        XCTAssertEqual(.real, type(for: 1, in: result))
    }
    
    func testRow() throws {
        let result = try result(for: "(1, 'Foo', 2.0)")
        XCTAssertEqual(.row([.integer, .text, .real]), result.type)
    }
    
    func testInRowSingleValue() throws {
        let result = try result(for: ":bar IN (1)")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.integer, type(for: "bar", in: result))
    }
    
    func testInRowMultipleValues() throws {
        let result = try result(for: ":bar IN (1, 2.0)")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.real, type(for: "bar", in: result))
    }
    
    func testInRowManyTypesUnUnifiable() throws {
        let result = try result(for: ":bar IN (1, 'Foo', 2.0)")
        XCTAssertEqual(.integer, result.type)
        XCTAssert(!result.diagnostics.elements.isEmpty)
    }
    
    func testInRowInferInputAsRow() throws {
        let result = try result(for: "1 IN :bar")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.row(.unknown(.integer)), type(for: "bar", in: result))
    }
    
    func testNotIn() throws {
        let result = try result(for: ":bar NOT IN (1, 2)")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.integer, type(for: "bar", in: result))
    }
    
    func testNull() throws {
        let result = try result(for: ":bar > 1 OR :bar == NULL")
        XCTAssertEqual(.integer, result.type)
        XCTAssertEqual(.optional(.integer), type(for: "bar", in: result))
    }
    
    func testFunctionOnLhs() {
        XCTAssertEqual(.integer, try check("unixepoch() + 1"))
    }
    
    func testExprInParens() {
        XCTAssertEqual(.row(.unnamed([.integer])), try check("(1 + 1) + 1"))
    }
    
    func scope(table: String, schema: String) throws -> Environment {
        var compiler = Compiler()
        _ = compiler.compile(migration: schema)
        guard let table = compiler.schema[table[...]] else { fatalError("'table' provided not in 'schema'") }
        var env = Environment()
        env.upsert(table.name, ty: table.type)
        table.columns.forEach { env.upsert($0, ty: $1) }
        return env
    }
    
    private func type(
        for index: BindParameterSyntax.Index,
        in output: Result
    ) -> Type? {
        return output.parameters.first{ $0.index == index }?.type
    }
    
    private func type(
        for name: Substring,
        in output: Result
    ) -> Type? {
        return output.parameters.first{ $0.name == name }?.type
    }
    
    private func name(
        for index: BindParameterSyntax.Index,
        in output: Result
    ) -> Substring? {
        return output.parameters.first{ $0.index == index }?.name
    }
    
    private func result(
        for source: String,
        in scope: Environment = Environment()
    ) throws -> Result {
        let (expr, exprDiags) = try Parsers.parse(
            source: source,
            parser: { try Parsers.expr(state: &$0) }
        )
        
        var exprTypeChecker = ExprTypeChecker(
            inferenceState: InferenceState(),
            env: scope,
            schema: Schema(),
            pragmas: []
        )
        var nameInferrer = NameInferrer()
        let type = exprTypeChecker.typeCheck(expr)
        _ = nameInferrer.infer(expr)
        
        let parameters = exprTypeChecker.inferenceState
            .parameterSolutions(defaultIfTyVar: true)
            .map { parameter in
                Parameter(
                    type: parameter.type,
                    index: parameter.index,
                    name: nameInferrer.parameterName(at: parameter.index),
                    locations: []
                )
            }
        
        return Result(
            parameters: parameters,
            type: exprTypeChecker.inferenceState
                .solution(for: type, defaultIfTyVar: true),
            diagnostics: exprTypeChecker.diagnostics
                .merging(exprDiags)
                .merging(exprTypeChecker.inferenceState.diagnostics)
        )
    }
    
    private func check(
        _ source: String,
        in scope: Environment = Environment()
    ) throws -> Type? {
        return try result(for: source, in: scope).type
    }
}
