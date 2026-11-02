//
//  StatementTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/16/25.
//

import PureSQL
import Testing

@Suite
struct StatementTests {
    struct ID: Equatable {
        let rawValue: Int
        
        init(_ rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    let idAdapter = AsIntAdapter<ID> {
        $0.rawValue
    } decode: {
        ID($0)
    }
    
    struct Adapters: PureSQL.Adapters {
        let id: AsIntAdapter<ID>
    }
    
    struct DoesNotNeedAdapters: RowDecodable, Equatable {
        let bar: Int
        let baz: String
        
        init(_ bar: Int, _ baz: String) {
            self.bar = bar
            self.baz = baz
        }
        
        init(row: borrowing Row, startingAt start: Int32) throws(SQLError) {
            self.bar = try row.value(at: 0)
            self.baz = try row.value(at: 1)
        }
    }
    
    struct NeedsAdapters: RowDecodableWithAdapters, Equatable {
        let bar: ID
        let baz: String
        
        init(_ bar: ID, _ baz: String) {
            self.bar = bar
            self.baz = baz
        }
        
        init(
            row: borrowing Row,
            startingAt start: Int32,
            adapters: Adapters
        ) throws(SQLError) {
            self.bar = try row.value(at: 0, using: adapters.id, storage: Int.self)
            self.baz = try row.value(at: 1)
        }
    }
    
    @Test func testBind() throws {
        try withStatement {
            """
            CREATE TABLE foo (id INTEGER);
            INSERT INTO foo VALUES (1);
            INSERT INTO foo VALUES (2);
            """
        } query: {
            "SELECT * FROM foo WHERE id = ?"
        } operation: { stmt in
            try stmt.bind(value: 2, to: 1)
            var cursor = Cursor<Int>(of: stmt)
            #expect(try cursor.next() == 2)
        }
    }

    @Test(arguments: [Int.max, Int.min, Int(Int32.max) + 1, Int(Int32.min) - 1])
    func testBindIntBeyondInt32Range(value: Int) throws {
        try withStatement {
            "CREATE TABLE foo (id INTEGER);"
        } query: {
            "SELECT ?"
        } operation: { stmt in
            try stmt.bind(value: value, to: 1)
            var cursor = Cursor<Int>(of: stmt)
            #expect(try cursor.next() == value)
        }
    }
    
    @Test func testBindWithAdapter() throws {
        try withStatement {
            """
            CREATE TABLE foo (id INTEGER);
            INSERT INTO foo VALUES (1);
            INSERT INTO foo VALUES (2);
            """
        } query: {
            "SELECT * FROM foo WHERE id = ?"
        } operation: { stmt in
            try stmt.bind(value: ID(2), to: 1, using: idAdapter, as: Int.self)
            var cursor = Cursor<Int>(of: stmt)
            #expect(try cursor.next() == 2)
        }
    }
    
    @Test func testBindWithAdapterOptionalDoesNotExist() throws {
        try withStatement {
            """
            CREATE TABLE foo (id INTEGER);
            INSERT INTO foo VALUES (1);
            INSERT INTO foo VALUES (2);
            """
        } query: {
            "SELECT * FROM foo WHERE id = ?"
        } operation: { stmt in
            try stmt.bind(value: nil, to: 1, using: idAdapter, as: Int.self)
            var cursor = Cursor<Int>(of: stmt)
            #expect(try cursor.next() == nil)
        }
    }
    
    @Test func fetchAll_RowDecodable() throws {
        try withTable { stmt in
            let values: [DoesNotNeedAdapters] = try stmt.fetchAll()
            #expect(values == [DoesNotNeedAdapters(1, "two"), DoesNotNeedAdapters(3, "four")])
        }
    }
    
    @Test func fetchOne_RowDecodable() throws {
        try withTable { stmt in
            let values: DoesNotNeedAdapters? = try stmt.fetchOne()
            #expect(values == DoesNotNeedAdapters(1, "two"))
        }
    }
    
    @Test func fetchOne_RowDecodable_NotOptional() throws {
        try withTable { stmt in
            let values: DoesNotNeedAdapters = try stmt.fetchOne()
            #expect(values == DoesNotNeedAdapters(1, "two"))
        }
    }

    @Test func fetchAll_RowDecodableWithAdapters() throws {
        try withTable { stmt in
            let values: [NeedsAdapters] = try stmt.fetchAll(adapters: Adapters(id: idAdapter))
            #expect(values == [NeedsAdapters(ID(1), "two"), NeedsAdapters(ID(3), "four")])
        }
    }
    
    @Test func fetchOne_RowDecodableWithAdapters() throws {
        try withTable { stmt in
            let values: NeedsAdapters? = try stmt.fetchOne(adapters: Adapters(id: idAdapter))
            #expect(values == NeedsAdapters(ID(1), "two"))
        }
    }
    
    @Test func fetchOne_RowDecodableWithAdapters_NotOptional() throws {
        try withTable { stmt in
            let values: NeedsAdapters = try stmt.fetchOne(adapters: Adapters(id: idAdapter))
            #expect(values == NeedsAdapters(ID(1), "two"))
        }
    }
    
    @Test func fetchAll_ValueWithAdapter() throws {
        // Note: The select * still works since we are just decoding the first column
        try withTable { stmt in
            let values: [ID] = try stmt.fetchAll(adapter: idAdapter, storage: Int.self)
            #expect(values == [ID(1), ID(3)])
        }
    }
    
    @Test func fetchOne_ValueWithAdapter() throws {
        // Note: The select * still works since we are just decoding the first column
        try withTable { stmt in
            let values: ID? = try stmt.fetchOne(adapter: idAdapter, storage: Int.self)
            #expect(values == ID(1))
        }
    }
    
    @Test func fetchOne_ValueWithAdapter_NotOptional() throws {
        // Note: The select * still works since we are just decoding the first column
        try withTable { stmt in
            let values: ID = try stmt.fetchOne(adapter: idAdapter, storage: Int.self)
            #expect(values == ID(1))
        }
    }
    
    private func withTable(operation: (consuming Statement) throws -> ()) throws {
        try withStatement {
            """
            CREATE TABLE foo (bar INTEGER, baz TEXt);
            INSERT INTO foo VALUES (1, 'two');
            INSERT INTO foo VALUES (3, 'four');
            """
        } query: {
            "SELECT * FROM foo ORDER BY bar ASC"
        } operation: { stmt in
            try operation(stmt)
        }
    }
    
    @Test func stepErrorHasTheMessageFromSQLite() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: ["CREATE TABLE foo (bar INTEGER PRIMARY KEY)"]
        )
        
        await #expect(throws: SQLError.sqlite(.sqliteConstraint, "UNIQUE constraint failed: foo.bar")) {
            try await pool.begin(.write) { tx in
                try tx.execute(sql: "INSERT INTO foo (bar) VALUES (1)")
                _ = try Statement("INSERT INTO foo (bar) VALUES (1)", transaction: tx).step()
            }
        }
    }
}
