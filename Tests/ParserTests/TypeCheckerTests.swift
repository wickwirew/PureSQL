//
//  TypeCheckerTests.swift
//
//
//  Created by Wes Wickwire on 10/21/24.
//

import Foundation
import XCTest
import Schema

@testable import Parser

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
        XCTAssertEqual(.integer, solution.type(for: .named("foo")))
        XCTAssertEqual(.real, solution.type(for: .named("bar")))
        XCTAssertEqual(.bool, solution.type(for: .named("baz")))
    }
    
    private func solution(for source: String, in scope: Scope = Scope()) throws -> Solution {
        let expr = try parse(source)
        var typeChecker = TypeChecker(scope: scope)
        return try typeChecker.check(expr)
    }
    
    private func check(_ source: String, in scope: Scope = Scope()) throws -> TypeName {
        let solution = try solution(for: source, in: scope)
        
        switch solution.type {
        case .nominal(let t):
            return t
        case .error, .var:
            return .any
        }
    }
    
    private func parse(_ source: String) throws -> Schema.Expression {
        return try ExprParser().parse(source)
    }
}
