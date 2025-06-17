//
//  SQLAnyTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/16/25.
//

import Foundation
import Testing
@testable import Feather

@Suite
struct SQLAnyTests {
    @Test func canDecodeToInteger() async throws {
        let db = try AnyDB.inMemory()
        try await db.insertFoo.execute(with: 1)
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.int(1)])
    }
    
    @Test func canDecodeToDouble() async throws {
        let db = try AnyDB.inMemory()
        try await db.insertFoo.execute(with: 1.5)
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.double(1.5)])
    }
    
    @Test func canDecodeToString() async throws {
        let db = try AnyDB.inMemory()
        try await db.insertFoo.execute(with: "baz")
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.string("baz")])
    }
    
    @Test func canDecodeToData() async throws {
        let db = try AnyDB.inMemory()
        let data = Data(repeating: 1, count: 5)
        try await db.insertFoo.execute(with: .data(data))
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.data(data)])
    }
    
    @Database
    struct AnyDB {
        @Query("INSERT INTO foo (bar) VALUES (?)")
        var insertFoo: InsertFooDatabaseQuery
        
        @Query("SELECT * FROM foo")
        var selectFoos: SelectFoosDatabaseQuery
        
        static var migrations: [String] {
            return ["CREATE TABLE foo (bar ANY);"]
        }
    }
}
