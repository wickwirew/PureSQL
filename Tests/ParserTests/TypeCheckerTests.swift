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
    
    func testTypeCheckBind() {
        XCTAssertEqual(.bool, try check(":fart = 1.0 + :foo > :bar + ?"))
    }
    
    private func check(_ source: String, in scope: Scope = Scope()) throws -> TypeName {
        let expr = try parse(source)
        var typeChecker = TypeChecker(scope: scope)
        let (result, sub) = try expr.accept(visitor: &typeChecker)
        
        print(result)
        print(sub[typeChecker.tyVarLookup[.named("foo")]!])
        print(Ty.var(typeChecker.tyVarLookup[.named("bar")]!).apply(sub))
        print(sub[typeChecker.tyVarLookup[.named("fart")]!])
        print(sub[typeChecker.tyVarLookup[.unnamed(0)]!])
        
        guard case let .nominal(ty) = result else {
            fatalError()
        }
        
        return ty
    }
    
    private func parse(_ source: String) throws -> Schema.Expression {
        return try ExprParser().parse(source)
    }
}
