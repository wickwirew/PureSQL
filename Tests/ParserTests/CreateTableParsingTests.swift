//
//  CreateTableParsingTests.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Foundation
import XCTest
import Schema
import OrderedCollections

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
        XCTAssertEqual(contraint.kind, .primaryKey(order: .asc, .none, autoincrement: false))
    }
    
    func testCreateTableWithPrimaryKeyAndConflict() throws {
        let table = try parse("CREATE TABLE user (id INT PRIMARY KEY ON CONFLICT REPLACE, name TEXT)")
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        let contraint = try XCTUnwrap(id.constraints.first)
        
        XCTAssertNil(contraint.name)
        XCTAssertEqual(contraint.kind, .primaryKey(order: .asc, .replace, autoincrement: false))
    }
    
    func testCreateTableWithPrimaryKeyAndConflictAndAutoincrement() throws {
        let table = try parse("CREATE TABLE user (id INT PRIMARY KEY ASC ON CONFLICT REPLACE AUTOINCREMENT, name TEXT)")
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        let contraint = try XCTUnwrap(id.constraints.first)
        
        XCTAssertNil(contraint.name)
        XCTAssertEqual(contraint.kind, .primaryKey(order: .asc, .replace, autoincrement: true))
    }
    
    func testCreateTableWithTheMostRediculousConstraints() throws {
        let table = try parse("CREATE TABLE user (id INTEGER PRIMARY KEY DESC ON CONFLICT REPLACE AUTOINCREMENT NOT NULL UNIQUE ON CONFLICT IGNORE DEFAULT 100, name TEXT)")
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        
        var constraints = id.constraints.makeIterator()
        
        let pk = try XCTUnwrap(constraints.next())
        let notNull = try XCTUnwrap(constraints.next())
        let unique = try XCTUnwrap(constraints.next())
        let defaultValue = try XCTUnwrap(constraints.next())
        XCTAssertNil(constraints.next())
        
        XCTAssertNil(pk.name)
        XCTAssertEqual(pk.kind, .primaryKey(order: .desc, .replace, autoincrement: true))
        
        XCTAssertNil(notNull.name)
        XCTAssertEqual(notNull.kind, .notNull(.none))
        
        XCTAssertNil(unique.name)
        XCTAssertEqual(unique.kind, .unique(.ignore))
        
        XCTAssertNil(defaultValue.name)
        XCTAssertEqual(defaultValue.kind, .default(.literal(.numeric(100))))
    }
    
    func testCreateTableWithALotOfConstraints() throws {
        let table = try parse("""
        CREATE TABLE user (
            id INT PRIMARY KEY ASC ON CONFLICT REPLACE AUTOINCREMENT, 
            name TEXT UNIQUE ON CONFLICT IGNORE DEFAULT 'Joe',
            age INT NOT NULL,
            agePlus1 INT GENERATED ALWAYS AS () VIRTUAL,
            countryId INT REFERENCES country(id) ON DELETE CASCADE
        )
        """)
        let columns = columns(table)
        
        let id = try XCTUnwrap(columns["id"])
        let pk = try XCTUnwrap(id.constraints.first)
        
        XCTAssertNil(pk.name)
        XCTAssertEqual(pk.kind, .primaryKey(order: .asc, .replace, autoincrement: true))
        
        let name = try XCTUnwrap(columns["name"])
        let nameUnique = try XCTUnwrap(name.constraints.first)
        let nameDefault = try XCTUnwrap(name.constraints.last)
        
        XCTAssertNil(nameUnique.name)
        XCTAssertEqual(nameUnique.kind, .unique(.ignore))
        XCTAssertEqual(nameDefault.kind, .default(.literal(.string("Joe"))))
        
        let age = try XCTUnwrap(columns["age"])
        let ageNotNull = try XCTUnwrap(age.constraints.first)
        
        XCTAssertNil(ageNotNull.name)
        XCTAssertEqual(ageNotNull.kind, .notNull(.none))
        
        let agePlus1 = try XCTUnwrap(columns["agePlus1"])
        let agePlus1Generated = try XCTUnwrap(agePlus1.constraints.first)
        
        // TODO: This will fail once expressions are parsed
        XCTAssertNil(agePlus1Generated.name)
        XCTAssertEqual(agePlus1Generated.kind, .generated(Expr(), .virtual))
        
        let countryId = try XCTUnwrap(columns["countryId"])
        let countryIdForeignKey = try XCTUnwrap(countryId.constraints.first)
        
        XCTAssertNil(countryIdForeignKey.name)
        XCTAssertEqual(countryIdForeignKey.kind, .foreignKey(ForeignKeyClause(foreignTable: "country", foreignColumns: ["id"], actions: [.onDo(.delete, .cascade)])))
    }
    
    func testCreateTableWithNamedConstraint() throws {
        let table = try parse("CREATE TABLE user (id INT PRIMARY KEY, name TEXT CONSTRAINT name_unique UNIQUE ON CONFLICT IGNORE)")
        let columns = columns(table)
        
        let name = try XCTUnwrap(columns["name"])
        
        let contraint = try XCTUnwrap(name.constraints.first)
        
        XCTAssertEqual(contraint.name, "name_unique")
        XCTAssertEqual(contraint.kind, .unique(.ignore))
    }
    
    private func parse(_ source: String) throws -> CreateTableStmt {
        let lexer = Lexer(source: source)
        var state = try ParserState(lexer)
        return try CreateTableParser()
            .parse(state: &state)
    }
    
    private func columns(_ table: CreateTableStmt) -> OrderedDictionary<Substring, ColumnDef> {
        guard case let .columns(columns) = table.kind else {
            return [:]
        }
        
        return columns
    }
}
