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
        XCTAssertEqual(.bool, try check("1 + 1 > 1"))
        XCTAssertEqual(.bool, try check("1 >= 1 - 1 * 2"))
        XCTAssertEqual(.bool, try check("1 > 1"))
        XCTAssertEqual(.bool, try check("1 < 1"))
        XCTAssertEqual(.bool, try check("1 <= 1"))
        XCTAssertEqual(.bool, try check("1 != 1 - 1 * 2"))
        XCTAssertEqual(.bool, try check("1 <> 1"))
        XCTAssertEqual(.bool, try check("1 = 1"))
        XCTAssertEqual(.bool, try check("1 == 1"))
    }
    
    func testTypeCheckBind() throws {
        let signature = signature(for: ":foo + 1 > :bar + 2.0 AND :baz")
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.real, signature.type(for: ":foo"))
        XCTAssertEqual(.real, signature.type(for: ":bar"))
        XCTAssertEqual(.bool, signature.type(for: ":baz"))
    }
    
    func testTypeCheckBind2() throws {
        let signature = signature(for: "1.0 + 2 * 3 * 4 * ?")
        XCTAssertEqual(.real, signature.output)
        XCTAssertEqual(.real, signature.type(for: 1))
    }
    
    func testNames() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER);
        """)
        
        let signature = signature(for: "bar = ?", in: scope)
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.optional(.integer), signature.type(for: 1))
        XCTAssertEqual("bar", signature.name(for: 1))
    }
    
    func testUnnamedBindParamNameNotRightNextToColumn() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER NOT NULL);
        """)
        
        let signature = signature(for: "bar + 1 = ?", in: scope)
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.integer, signature.type(for: 1))
        XCTAssertEqual("bar", signature.name(for: 1))
    }
    
    func testUnnamedBindParamNameNotRightNextToColumn2() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER NOT NULL);
        """)
        
        let signature = signature(for: "1 + bar = ?", in: scope)
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.integer, signature.type(for: 1))
        XCTAssertEqual("bar", signature.name(for: 1))
    }
    
    func testTypeCheckBetween() throws {
        let signature = signature(for: "1 BETWEEN 1 AND ?")
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.integer, signature.type(for: 1))
    }
    
    func testTypeFunction() throws {
        XCTAssertEqual(.integer, signature(for: "MAX(1)").output)
        XCTAssertEqual(.real, signature(for: "MAX(1.0, 1)").output)
        XCTAssertEqual(.real, signature(for: "MAX(1, 1.0)").output)
        XCTAssertEqual(.real, signature(for: "MAX(1, 1, 1.0)").output)
        XCTAssertEqual(.real, signature(for: "MAX(1, 1, 1.0, 1)").output)
        XCTAssertEqual(.real, signature(for: "MAX(1, 1, 1, 1.0)").output)
    }
    
    func testTypeFunctionComplex() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar REAL NOT NULL);
        """)
        
        let signature = signature(for: "MAX(1, 1, bar + 1, 1)", in: scope)
        XCTAssertEqual(.real, signature.output)
    }
    
    func testTypeFunctionInputGetBound() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar REAL NOT NULL);
        """)
        
        let signature = signature(for: "MAX(1, 1, bar + ?, 1)", in: scope)
        XCTAssertEqual(.real, signature.output)
        XCTAssertEqual(.real, signature.type(for: 1))
    }
    
    func testErrors() throws {
        let signature = signature(for: "'a' + 'b'")
        XCTAssertEqual(.text, signature.output)
    }
    
    func testCast() throws {
        let signature = signature(for: "CAST(1 AS TEXT)")
        XCTAssertEqual(.text, signature.output)
    }
    
    func testCaseWhenThenWithCaseExpr() throws {
        let signature = signature(for: "CASE 1 WHEN ? THEN '' WHEN 3 THEN '' ELSE '' END")
        XCTAssertEqual(.text, signature.output)
        XCTAssertEqual(.integer, signature.type(for: 1))
    }
    
    func testCaseWhenThenWithNoCaseExpr() throws {
        let signature = signature(for: "CASE WHEN ? + 1 THEN '' WHEN 3.0 THEN '' ELSE '' END")
        XCTAssertEqual(.text, signature.output)
        XCTAssertEqual(.real, signature.type(for: 1))
    }
    
    func testRow() throws {
        let signature = signature(for: "(1, 'Foo', 2.0)")
        XCTAssertEqual(.row([.integer, .text, .real]), signature.output)
    }
    
    func testInRowSingleValue() throws {
        let signature = signature(for: ":bar IN (1)")
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.integer, signature.type(for: ":bar"))
    }
    
    func testInRowMultipleValues() throws {
        let signature = signature(for: ":bar IN (1, 2.0)")
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.real, signature.type(for: ":bar"))
    }
    
    func testInRowManyTypesUnUnifiable() throws {
        let (signature, diagnostics) = signature(for: ":bar IN (1, 'Foo', 2.0)")
        XCTAssertEqual(.bool, signature.output)
        XCTAssert(!diagnostics.elements.isEmpty)
    }
    
    func testInRowInferInputAsRow() throws {
        let signature = signature(for: "1 IN :bar")
        XCTAssertEqual(.bool, signature.output)
        XCTAssertEqual(.row(.unknown(.integer)), signature.type(for: ":bar"))
    }
    
    func scope(table: String, schema: String) throws -> Environment {
        var compiler = SchemaCompiler()
        compiler.compile(schema)
        guard let table = compiler.schema[table[...]] else { fatalError("'table' provided not in 'schema'") }
        var env = Environment()
        env.upsert(table.name, ty: table.type)
        table.columns.forEach { env.upsert($0, ty: $1) }
        return env
    }
    
    private func signature(
        for source: String,
        in scope: Environment = Environment()
    ) -> Signature {
        let (expr, _) = Parsers.parse(source: source, parser: { Parsers.expr(state: &$0) })
        var typeInferrer = TypeChecker(env: scope, schema: [:])
        let signature = typeInferrer.signature(for: expr)
        return signature
    }
    
    @_disfavoredOverload
    private func signature(
        for source: String,
        in scope: Environment = Environment()
    ) -> (Signature, Diagnostics) {
        let (expr, exprDiags) = Parsers.parse(source: source, parser: { Parsers.expr(state: &$0) })
        var typeInferrer = TypeChecker(env: scope, schema: [:])
        let signature = typeInferrer.signature(for: expr)
        let diagnostics = typeInferrer.diagnostics.merging(exprDiags)
        return (signature, diagnostics)
    }
    
    private func check(
        _ source: String,
        in scope: Environment = Environment()
    ) throws -> Type? {
        return signature(for: source, in: scope).output
    }
}
