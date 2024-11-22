//
//  ParserTests.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import XCTest

@testable import Compiler

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


// MARK: - Ty

extension ParserTests {
    func testAllTypes() {
        XCTAssertEqual(TypeName(name: "INT", args: nil), try execute(parser: TypeNameParser(), source: "INT"))
        XCTAssertEqual(TypeName(name: "INTEGER", args: nil), try execute(parser: TypeNameParser(), source: "INTEGER"))
        XCTAssertEqual(TypeName(name: "TINYINT", args: nil), try execute(parser: TypeNameParser(), source: "TINYINT"))
        XCTAssertEqual(TypeName(name: "SMALLINT", args: nil), try execute(parser: TypeNameParser(), source: "SMALLINT"))
        XCTAssertEqual(TypeName(name: "MEDIUMINT", args: nil), try execute(parser: TypeNameParser(), source: "MEDIUMINT"))
        XCTAssertEqual(TypeName(name: "BIGINT", args: nil), try execute(parser: TypeNameParser(), source: "BIGINT"))
        XCTAssertEqual(TypeName(name: "UNSIGNED BIG INT", args: nil), try execute(parser: TypeNameParser(), source: "UNSIGNED BIG INT"))
        XCTAssertEqual(TypeName(name: "INT2", args: nil), try execute(parser: TypeNameParser(), source: "INT2"))
        XCTAssertEqual(TypeName(name: "INT8", args: nil), try execute(parser: TypeNameParser(), source: "INT8"))
        XCTAssertEqual(TypeName(name: "NUMERIC", args: nil), try execute(parser: TypeNameParser(), source: "NUMERIC"))
        XCTAssertEqual(TypeName(name: "BOOLEAN", args: nil), try execute(parser: TypeNameParser(), source: "BOOLEAN"))
        XCTAssertEqual(TypeName(name: "DATE", args: nil), try execute(parser: TypeNameParser(), source: "DATE"))
        XCTAssertEqual(TypeName(name: "DATETIME", args: nil), try execute(parser: TypeNameParser(), source: "DATETIME"))
        XCTAssertEqual(TypeName(name: "REAL", args: nil), try execute(parser: TypeNameParser(), source: "REAL"))
        XCTAssertEqual(TypeName(name: "DOUBLE", args: nil), try execute(parser: TypeNameParser(), source: "DOUBLE"))
        XCTAssertEqual(TypeName(name: "DOUBLE PRECISION", args: nil), try execute(parser: TypeNameParser(), source: "DOUBLE PRECISION"))
        XCTAssertEqual(TypeName(name: "FLOAT", args: nil), try execute(parser: TypeNameParser(), source: "FLOAT"))
        XCTAssertEqual(TypeName(name: "TEXT", args: nil), try execute(parser: TypeNameParser(), source: "TEXT"))
        XCTAssertEqual(TypeName(name: "CLOB", args: nil), try execute(parser: TypeNameParser(), source: "CLOB"))
        XCTAssertEqual(TypeName(name: "BLOB", args: nil), try execute(parser: TypeNameParser(), source: "BLOB"))
        XCTAssertEqual(TypeName(name: "DECIMAL", args: .two(1, 2)), try execute(parser: TypeNameParser(), source: "DECIMAL(1, 2)"))
        XCTAssertEqual(TypeName(name: "CHARACTER", args: .one(1)), try execute(parser: TypeNameParser(), source: "CHARACTER(1)"))
        XCTAssertEqual(TypeName(name: "VARCHAR", args: .one(1)), try execute(parser: TypeNameParser(), source: "VARCHAR(1)"))
        XCTAssertEqual(TypeName(name: "VARYING CHARACTER", args: .one(1)), try execute(parser: TypeNameParser(), source: "VARYING CHARACTER(1)"))
        XCTAssertEqual(TypeName(name: "NCHAR", args: .one(1)), try execute(parser: TypeNameParser(), source: "NCHAR(1)"))
        XCTAssertEqual(TypeName(name: "NVARCHAR", args: .one(1)), try execute(parser: TypeNameParser(), source: "NVARCHAR(1)"))
        XCTAssertEqual(TypeName(name: "NATIVE CHARACTER", args: .one(1)), try execute(parser: TypeNameParser(), source: "NATIVE CHARACTER(1)"))
    }
    
    func testErrorIsThrownOn3Args() {
        XCTAssertThrowsError(try execute(parser: TypeNameParser(), source: "DECIMAL(1, 2, 3)"))
    }
    
    func testErrorIsThrownOnIncorrectArgNumber() {
        XCTAssertThrowsError(try execute(parser: TypeNameParser(), source: "DECIMAL(1, 2, 3)"))
    }
}


// MARK: - ConflictClause

extension ParserTests {
    func testTableOptions() throws {
        try check(sqlFile: "TableOptions", parser: TableOptionsParser())
    }
    
    func testConflictClause() throws {
        try check(sqlFile: "ConflictClause", parser: ConfictClauseParser())
    }
    
    func testForeignKeyClause() throws {
        try check(sqlFile: "ForeignKeyClause", parser: ForeignKeyClauseParser())
    }
    
    func testOrder() throws {
        try check(sqlFile: "Order", parser: OrderParser())
    }
    
    func testColumnConstraint() throws {
        try check(sqlFile: "ColumnConstraint", parser: ColumnConstraintParser())
    }
    
    func testColumnDefinition() throws {
        try check(sqlFile: "ColumnDefinition", parser: ColumnDefinitionParser())
    }
    
    func testAlterTable() throws {
        try check(sqlFile: "AlterTable", parser: AlterTableParser())
    }
    
    func testSignedNumber() throws {
        try check(sqlFile: "SignedNumber", parser: SignedNumberParser())
    }
    
    func testTypeName() throws {
        try check(sqlFile: "TypeName", parser: TypeNameParser())
    }
}
