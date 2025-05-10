//
//  DatabaseMacroTests.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

import Testing
import Feather

@Suite
struct DatabaseMacroTests {
    @Test func insertAndSelect() async throws {
        let database = try TestDB.inMemory()
        
        try await database.insertFooQuery.execute(with: .init(bar: 1, baz: "Meow", qux: 1))
        
        let foos = try await database.selectFooQuery.execute()
        
        for foo in foos {
            print(foo)
        }
    }
    
    @Database
    struct TestDB {
        @Query("SELECT * FROM foo")
        var selectFooQuery: SelectFooDatabaseQuery

        @Query("INSERT INTO foo (bar, baz, qux) VALUES (?, ?, ?)", inputName: "Meow")
        var insertFooQuery: InsertFooDatabaseQuery
        
        static var migrations: [String] {
            return [
                "CREATE TABLE foo (bar INTEGER, baz TEXT, qux ANY);"
            ]
        }
    }
}
