//
//  SQLAnyTests.swift
//  Otter
//
//  Created by Wes Wickwire on 6/16/25.
//

import Foundation
@testable import Otter
import Testing

@Suite
struct SQLAnyTests {
    @Test func canDecodeToInteger() async throws {
        let db = try AnyDB.inMemory()
        try await db.insertFoo.execute(1)
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.int(1)])
    }
    
    @Test func canDecodeToDouble() async throws {
        let db = try AnyDB.inMemory()
        try await db.insertFoo.execute(1.5)
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.double(1.5)])
    }
    
    @Test func canDecodeToString() async throws {
        let db = try AnyDB.inMemory()
        try await db.insertFoo.execute("baz")
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.string("baz")])
    }
    
    @Test func canDecodeToData() async throws {
        let db = try AnyDB.inMemory()
        let data = Data(repeating: 1, count: 5)
        try await db.insertFoo.execute(.data(data))
        let foos = try await db.selectFoos.execute().compactMap(\.bar)
        #expect(foos == [.data(data)])
    }
    
    @Database
    struct AnyDB {
        @Query("INSERT INTO foo (bar) VALUES (?)")
        var insertFoo: any InsertFooQuery
        
        @Query("SELECT * FROM foo")
        var selectFoos: any SelectFoosQuery
        
        static let migrations: [String] = ["CREATE TABLE foo (bar ANY);"]
    }
}
