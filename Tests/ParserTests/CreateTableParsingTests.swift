//
//  CreateTableParsingTests.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Foundation
import XCTest
import Schema

@testable import Parser

class CreateTableParsingTests: XCTestCase {
    func testCreateTable() throws {
        let table = try parse("CREATE TABLE user (id INT, name TEXT)")
        let columns = columns(table)
        
        XCTAssertEqual(table.name, "user")
        XCTAssertEqual(columns.count, 2)
        
        let id = try XCTUnwrap(columns["id"])
        let name = try XCTUnwrap(columns["name"])
        
        XCTAssertEqual(id.name, "id")
        XCTAssertEqual(id.type, .int)
        XCTAssertEqual(id.constraints, [])
        XCTAssertEqual(name.name, "name")
        XCTAssertEqual(name.type, .text)
        XCTAssertEqual(name.constraints, [])
    }
    
    func testCreateTableWithPrimaryKey() throws {
        let table = try parse("CREATE TABLE user (id INT PRIMARY KEY, name TEXT)")
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        let contraint = try XCTUnwrap(id.constraints.first)
        
        XCTAssertNil(contraint.name)
        XCTAssertEqual(contraint.kind, .primaryKey(order: nil, nil, autoincrement: false))
    }
    
    func testCreateTableWithPrimaryKeyAndConflict() throws {
        let table = try parse("CREATE TABLE user (id INT PRIMARY KEY ON CONFLICT REPLACE, name TEXT)")
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        let contraint = try XCTUnwrap(id.constraints.first)
        
        XCTAssertNil(contraint.name)
        XCTAssertEqual(contraint.kind, .primaryKey(order: nil, .replace, autoincrement: false))
    }
    
    func testCreateTableWithPrimaryKeyAndConflictAndAutoincrement() throws {
        let table = try parse("CREATE TABLE user (id INT PRIMARY KEY ASC ON CONFLICT REPLACE AUTOINCREMENT, name TEXT)")
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        let contraint = try XCTUnwrap(id.constraints.first)
        
        XCTAssertNil(contraint.name)
        XCTAssertEqual(contraint.kind, .primaryKey(order: .asc, .replace, autoincrement: true))
    }
    
    private func parse(_ source: String) throws -> CreateTableStmt {
        let lexer = Lexer(source: source)
        var parser = try Parser(lexer: lexer)
        let stmt = try parser.next()
        
        guard case let .createTable(createTable) = stmt else {
            return try XCTUnwrap(nil)
        }
        
        return createTable
    }
    
    private func columns(_ table: CreateTableStmt) -> [Substring: ColumnDef] {
        guard case let .columns(columns) = table.kind else {
            return [:]
        }
        
        return columns
    }
}
