//
//  RowTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 9/6/25.
//

import Testing
import Foundation

@testable import PureSQL

@Suite
struct RowTests {
    @Test func valueAtAllPrimitives() throws {
        try withCursor {
            """
            CREATE TABLE foo (int INTEGER, text TEXT, real REAL, blob BLOB, any ANY);
            INSERT INTO foo VALUES (1, 'two', 3, x'04', 5);
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            let int = try row?.value(at: 0, as: Int.self)
            let text = try row?.value(at: 1, as: String.self)
            let real = try row?.value(at: 2, as: Double.self)
            let blob = try row?.value(at: 3, as: Data.self)
            let any = try row?.value(at: 4, as: SQLAny.self)
            #expect(int == 1)
            #expect(text == "two")
            #expect(real == 3)
            #expect(blob == Data([0x4]))
            #expect(any == .int(5))
        }
    }
    
    @Test func valueAtNilValues() throws {
        try withCursor {
            """
            CREATE TABLE foo (foo INTEGER, bar TEXT);
            INSERT INTO foo VALUES (NULL, NULL);
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            let foo = try row?.value(at: 0, as: Int?.self)
            let bar = try row?.value(at: 1, as: String?.self)
            #expect(foo == nil)
            #expect(bar == nil)
        }
    }
    
    @Test func valueAtWithAdapter() throws {
        let adapter = AsIntAdapter<String> { str in
            Int(str) ?? 0
        } decode: { int in
            int.description
        }
        
        try withCursor {
            """
            CREATE TABLE foo (foo INTEGER);
            INSERT INTO foo VALUES (123);
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            let foo = try row?.value(at: 0, using: adapter, storage: Int.self)
            #expect(foo == "123")
        }
    }
    
    @Test func optionalValueAtWithAdapter() throws {
        let adapter = AsIntAdapter<String> { str in
            Int(str) ?? 0
        } decode: { int in
            int.description
        }
        
        try withCursor {
            """
            CREATE TABLE foo (bar INTEGER);
            INSERT INTO foo VALUES (NULL);
            INSERT INTO foo VALUES (123);
            """
        } query: {
            "SELECT * FROM foo ORDER BY bar NULLS FIRST"
        } operation: { cursor in
            let firstRow = try cursor.nextRow()
            let first = try firstRow?.optionalValue(at: 0, using: adapter, storage: Int.self)
            #expect(first == nil)
            let secondRow = try cursor.nextRow()
            let second = try secondRow?.optionalValue(at: 0, using: adapter, storage: Int.self)
            #expect(second == "123")
        }
    }
    
    @Test func embdededStruct() throws {
        struct Foo: RowDecodable {
            let bar: Int
            let baz: String
            
            init(row: borrowing Row, startingAt start: Int32) throws(SQLError) {
                self.bar = try row.value(at: 0)
                self.baz = try row.value(at: 1)
            }
        }
        
        try withCursor {
            """
            CREATE TABLE foo (bar INTEGER NOT NULL, baz TEXT NOT NULL);
            INSERT INTO foo VALUES (123, "text");
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            let foo = try row?.embedded(at: 0, as: Foo.self)
            #expect(foo?.bar == 123)
            #expect(foo?.baz == "text")
        }
    }
    
    @Test func optionallyEmbeddedStructExists() throws {
        struct Foo: RowDecodable {
            let bar: Int
            let baz: String
            
            init(row: borrowing Row, startingAt start: Int32) throws(SQLError) {
                self.bar = try row.value(at: 0)
                self.baz = try row.value(at: 1)
            }
        }
        
        try withCursor {
            """
            CREATE TABLE foo (bar INTEGER NOT NULL, baz TEXT NOT NULL);
            INSERT INTO foo VALUES (123, "text");
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            let foo = try row?.optionallyEmbedded(at: 0, as: Foo.self)
            #expect(foo?.bar == 123)
            #expect(foo?.baz == "text")
        }
    }
    
    @Test func optionallyEmbeddedStructDoesNotExist() throws {
        struct Foo: RowDecodable {
            let bar: Int
            let baz: String
            
            static var nonOptionalIndices: [Int32] { [0, 1] }
            
            init(row: borrowing Row, startingAt start: Int32) throws(SQLError) {
                self.bar = try row.value(at: 0)
                self.baz = try row.value(at: 1)
            }
        }
        
        try withCursor {
            """
            CREATE TABLE foo (bar INTEGER, baz TEXT);
            INSERT INTO foo VALUES (NULL, NULL);
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            let foo = try row?.optionallyEmbedded(at: 0, as: Foo.self)
            #expect(foo == nil)
        }
    }
    
    @Test func hasValue() throws {
        try withCursor {
            """
            CREATE TABLE foo (bar INTEGER, baz INTEGER);
            INSERT INTO foo VALUES (NULL, 1);
            """
        } query: {
            "SELECT * FROM foo"
        } operation: { cursor in
            let row = try cursor.nextRow()
            #expect(try row?.hasValue(at: 0) == false)
            #expect(try row?.hasValue(at: 1) == true)
        }
    }
}
