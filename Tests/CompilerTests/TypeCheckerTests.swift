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
        let solution = try solution(for: ":foo + 1 > :bar + 2.0 AND :baz")
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.real, solution.type(for: .named(":foo")))
        XCTAssertEqual(.real, solution.type(for: .named(":bar")))
        XCTAssertEqual(.bool, solution.type(for: .named(":baz")))
    }
    
    func testTypeCheckBind2() throws {
        let solution = try solution(for: "1.0 + 2 * 3 * 4 * ?")
        XCTAssertEqual(.real, solution.type)
        XCTAssertEqual(.real, solution.type(for: .unnamed(1)))
    }
    
    func testNames() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER);
        """)
        
        var solution = try solution(for: "bar = ?", in: scope)
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.optional(.integer), solution.type(for: .unnamed(1)))
        XCTAssertEqual("bar", solution.name(for: 1))
    }
    
    func testUnnamedBindParamNameNotRightNextToColumn() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER NOT NULL);
        """)
        
        var solution = try solution(for: "bar + 1 = ?", in: scope)
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.integer, solution.type(for: .unnamed(1)))
        XCTAssertEqual("bar", solution.name(for: 1))
    }
    
    func testUnnamedBindParamNameNotRightNextToColumn2() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar INTEGER NOT NULL);
        """)
        
        var solution = try solution(for: "1 + bar = ?", in: scope)
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.integer, solution.type(for: .unnamed(1)))
        XCTAssertEqual("bar", solution.name(for: 1))
    }
    
    func testTypeCheckBetween() throws {
        let solution = try solution(for: "1 BETWEEN 1 AND ?")
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.integer, solution.type(for: .unnamed(1)))
    }
    
    func testTypeFunction() throws {
        XCTAssertEqual(.integer, try solution(for: "MAX(1)").type)
        XCTAssertEqual(.real, try solution(for: "MAX(1.0, 1)").type)
        XCTAssertEqual(.real, try solution(for: "MAX(1, 1.0)").type)
        XCTAssertEqual(.real, try solution(for: "MAX(1, 1, 1.0)").type)
        XCTAssertEqual(.real, try solution(for: "MAX(1, 1, 1.0, 1)").type)
        XCTAssertEqual(.real, try solution(for: "MAX(1, 1, 1, 1.0)").type)
    }
    
    func testTypeFunctionComplex() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar REAL NOT NULL);
        """)
        
        let solution = try solution(for: "MAX(1, 1, bar + 1, 1)", in: scope)
        XCTAssertEqual(.real, solution.type)
    }
    
    func testTypeFunctionInputGetBound() throws {
        let scope = try scope(table: "foo", schema: """
        CREATE TABLE foo(bar REAL NOT NULL);
        """)
        
        let solution = try solution(for: "MAX(1, 1, bar + ?, 1)", in: scope)
        XCTAssertEqual(.real, solution.type)
        XCTAssertEqual(.real, solution.type(for: .unnamed(1)))
    }
    
    func testErrors() throws {
        let solution = try solution(for: "'a' + 'b'")
        XCTAssertEqual(.text, solution.type)
    }
    
    func testCast() throws {
        let solution = try solution(for: "CAST(1 AS TEXT)")
        XCTAssertEqual(.text, solution.type)
    }
    
    func testCaseWhenThenWithCaseExpr() throws {
        let solution = try solution(for: "CASE 1 WHEN ? THEN '' WHEN 3 THEN '' ELSE '' END")
        XCTAssertEqual(.text, solution.type)
        XCTAssertEqual(.integer, solution.type(for: .unnamed(1)))
    }
    
    func testCaseWhenThenWithNoCaseExpr() throws {
        let solution = try solution(for: "CASE WHEN ? + 1 THEN '' WHEN 3.0 THEN '' ELSE '' END")
        XCTAssertEqual(.text, solution.type)
        XCTAssertEqual(.real, solution.type(for: .unnamed(1)))
    }
    
    func testRow() throws {
        let solution = try solution(for: "(1, 'Foo', 2.0)")
        XCTAssertEqual(.row([.integer, .text, .real]), solution.type)
    }
    
    func testInRow() throws {
        let solution = try solution(for: ":bar IN (1, 'Foo', 2.0)")
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.row([.integer, .text, .real]), solution.type(for: .named(":bar")))
    }
    
    func testInRowInferInputAsRow() throws {
        let solution = try solution(for: "1 IN :bar")
        XCTAssertEqual(.bool, solution.type)
        XCTAssertEqual(.row([.integer]), solution.type(for: .named(":bar")))
    }
    
    func scope(table: String, schema: String) throws -> Environment {
        var compiler = Compiler()
        try compiler.compile(schema)
        guard let table = compiler.schema[table[...]] else { fatalError("'table' provided not in 'schema'") }
        var env = Environment()
        env.upsert(table.name, ty: table.type)
        table.columns.forEach { env.upsert($0, ty: $1) }
        return env
    }
    
    private func solution(for source: String, in scope: Environment = Environment()) throws -> Solution {
        let (expr, d1) = try Parsers.parse(source: source, parser: { try Parsers.expr(state: &$0) })
        var typeInferrer = TypeInferrer(env: scope)
        let (solution, d2) = typeInferrer.check(expr)
        for d in (d1.diagnostics + d2.diagnostics) {
            print(d.message)
        }
        return solution
    }
    
    private func check(_ source: String, in scope: Environment = Environment()) throws -> Ty {
        return try solution(for: source, in: scope).type
    }
}
