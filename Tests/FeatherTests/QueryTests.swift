//
//  QueryTests.swift
//  Feather
//
//  Created by Wes Wickwire on 2/18/25.
//

import Testing

@testable import Feather

@Suite
struct QueryTests {
    @Test func testQuery() async throws {
        let pool = try createDatabase()
        let insert = insertQuery(database: pool)
        
        let foo1 = Foo(bar: 1, baz: "bar1")
        let foo2 = Foo(bar: 2, baz: "bar2")
        let foo3 = Foo(bar: 3, baz: "bar3")
        
        try await insert.execute(with: foo1)
        try await insert.execute(with: foo2)
        try await insert.execute(with: foo3)
        
        let foos = try await selectAllFooQuery(database: pool).execute()
        
        #expect(foos.count == 3)
    }
    
//    @Test func testMacroQuery() async throws {
//        let pool = try ConnectionPool(path: ":memory:", limit: 1, migrations: TestDB.migrations)
//        
//        try await TestDB.insertFoo.execute(with: .init(bar: 1, baz: "one"), in: pool)
//        try await TestDB.insertFoo.execute(with: .init(bar: 2, baz: "two"), in: pool)
//        
//        let foos = try await TestDB.fetchFoos.execute(in: pool)
//        #expect(foos.count == 2)
//    }
    
    struct Foo: RowDecodable {
        let bar: Int
        let baz: String?
        
        init(bar: Int, baz: String?) {
            self.bar = bar
            self.baz = baz
        }
        
        init(row: borrowing Row, startingAt start: Int32) throws(FeatherError) {
            self.bar = try row.value(at: 0)
            self.baz = try row.value(at: 1)
        }
    }
    
    private func selectAllFooQuery(database: any Connection) -> any DatabaseQuery<(), [Foo]> {
        return AnyDatabaseQuery<(), [Foo]>(.read, in: database) { input, transaction in
            let statement = try Statement(in: transaction) {
                "SELECT * FROM foo;"
            }
            
            return try statement.fetchAll(of: Foo.self)
        }
    }
    
    private func insertQuery(database: any Connection) -> any DatabaseQuery<Foo, ()> {
        return AnyDatabaseQuery<Foo, ()>(.write, in: database) { input, transaction in
            let statement = try Statement(in: transaction) {
                "INSERT INTO foo (bar, baz) VALUES (?, ?)"
            } bind: { statement in
                try statement.bind(value: input.bar, to: 1)
                try statement.bind(value: input.baz, to: 2)
            }
            
            _ = try statement.step()
        }
    }
    
    private func createDatabase() throws -> ConnectionPool {
        return try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: [
                "CREATE TABLE foo (bar INTEGER PRIMARY KEY, baz TEXT)"
            ]
        )
    }
//    
//    @Database
//    struct TestDB: Database {
//        static var migrations: [String] {
//            return [
//                "CREATE TABLE foo (bar INTEGER PRIMARY KEY, baz TEXT)"
//            ]
//        }
//        
//        static var queries: [String] {
//            return [
//                """
//                DEFINE QUERY fetchFoos AS
//                SELECT * FROM foo;
//                
//                DEFINE QUERY insertFoo AS
//                INSERT INTO foo (bar, baz) VALUES (?, ?);
//                """,
//            ]
//        }
//    }
}
