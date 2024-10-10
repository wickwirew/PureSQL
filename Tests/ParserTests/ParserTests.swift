//
//  ParserTests.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import XCTest
import Schema

@testable import Parser

/// Just tests for the smaller, less complex parsers that dont really need their own file.
final class ParserTests: XCTestCase {
    private func parserState(_ source: String) throws -> ParserState {
        return try ParserState(Lexer(source: source))
    }
    
    private func execute<P: Parser>(parser: P, source: String) throws -> P.Output {
        var state = try parserState(source)
        return try parser.parse(state: &state)
    }
}

// MARK: - TableOptions

extension ParserTests {
    func testTableOptionsEmpty() throws {
        let result = try execute(parser: TableOptionsParser(), source: "")
        
        XCTAssertEqual(result, [])
    }
    
    func testTableOptionsWithoutRowId() throws {
        let result = try execute(parser: TableOptionsParser(), source: "WITHOUT ROWID")
        XCTAssertEqual(result, [.withoutRowId])
    }
    
    func testTableOptionsStrict() throws {
        let result = try execute(parser: TableOptionsParser(), source: "STRICT")
        XCTAssertEqual(result, [.strict])
    }
    
    func testTableOptionsAll() throws {
        let result = try execute(parser: TableOptionsParser(), source: "WITHOUT ROWID, STRICT")
        XCTAssertEqual(result, [.strict, .withoutRowId])
    }
}

// MARK: - Ty

extension ParserTests {
    func testAllTypes() {
        XCTAssertEqual(.int, try execute(parser: TyParser(), source: "INT"))
        XCTAssertEqual(.integer, try execute(parser: TyParser(), source: "INTEGER"))
        XCTAssertEqual(.tinyint, try execute(parser: TyParser(), source: "TINYINT"))
        XCTAssertEqual(.smallint, try execute(parser: TyParser(), source: "SMALLINT"))
        XCTAssertEqual(.mediumint, try execute(parser: TyParser(), source: "MEDIUMINT"))
        XCTAssertEqual(.bigint, try execute(parser: TyParser(), source: "BIGINT"))
        XCTAssertEqual(.unsignedBigInt, try execute(parser: TyParser(), source: "UNSIGNED BIG INT"))
        XCTAssertEqual(.int2, try execute(parser: TyParser(), source: "INT2"))
        XCTAssertEqual(.int8, try execute(parser: TyParser(), source: "INT8"))
        XCTAssertEqual(.numeric, try execute(parser: TyParser(), source: "NUMERIC"))
        XCTAssertEqual(.boolean, try execute(parser: TyParser(), source: "BOOLEAN"))
        XCTAssertEqual(.date, try execute(parser: TyParser(), source: "DATE"))
        XCTAssertEqual(.datetime, try execute(parser: TyParser(), source: "DATETIME"))
        XCTAssertEqual(.real, try execute(parser: TyParser(), source: "REAL"))
        XCTAssertEqual(.double, try execute(parser: TyParser(), source: "DOUBLE"))
        XCTAssertEqual(.doublePrecision, try execute(parser: TyParser(), source: "DOUBLE PRECISION"))
        XCTAssertEqual(.float, try execute(parser: TyParser(), source: "FLOAT"))
        XCTAssertEqual(.text, try execute(parser: TyParser(), source: "TEXT"))
        XCTAssertEqual(.clob, try execute(parser: TyParser(), source: "CLOB"))
        XCTAssertEqual(.blob, try execute(parser: TyParser(), source: "BLOB"))
        XCTAssertEqual(.decimal(1, 2), try execute(parser: TyParser(), source: "DECIMAL(1, 2)"))
        XCTAssertEqual(.character(1), try execute(parser: TyParser(), source: "CHARACTER(1)"))
        XCTAssertEqual(.varchar(1), try execute(parser: TyParser(), source: "VARCHAR(1)"))
        XCTAssertEqual(.varyingCharacter(1), try execute(parser: TyParser(), source: "VARYING CHARACTER(1)"))
        XCTAssertEqual(.nchar(1), try execute(parser: TyParser(), source: "NCHAR(1)"))
        XCTAssertEqual(.nvarchar(1), try execute(parser: TyParser(), source: "NVARCHAR(1)"))
        XCTAssertEqual(.nativeCharacter(1), try execute(parser: TyParser(), source: "NATIVE CHARACTER(1)"))
    }
    
    func testErrorIsThrownOn3Args() {
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "DECIMAL(1, 2, 3)"))
    }
    
    func testErrorIsThrownOnIncorrectArgNumber() {
        // If it needs 1, it gets 2, and if it needs 2 it gets 1 to throw the error
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "DECIMAL(1)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "CHARACTER(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "VARCHAR(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "VARYING CHARACTER(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "NCHAR(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "NVARCHAR(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "NATIVE CHARACTER(1, 2)"))
    }
}

// MARK: - Symbol

extension ParserTests {
    func testSymbol() {
        XCTAssertEqual("userId", try execute(parser: SymbolParser(), source: "userId"))
    }
    
    func testKeyword() {
        XCTAssertThrowsError(try execute(parser: SymbolParser(), source: "SELECT"))
    }
}

// MARK: - SignedNumber

extension ParserTests {
    func testNoSign() {
        XCTAssertEqual(123, try execute(parser: SignedNumberParser(), source: "123"))
    }
    
    func testPositiveSign() {
        XCTAssertEqual(123, try execute(parser: SignedNumberParser(), source: "+123"))
    }
    
    func testNegativeSign() {
        XCTAssertEqual(-123, try execute(parser: SignedNumberParser(), source: "-123"))
    }
}
