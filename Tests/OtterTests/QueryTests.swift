//
//  QueryTests.swift
//  Otter
//
//  Created by Wes Wickwire on 2/18/25.
//

import Testing

@testable import Otter

@Suite
struct QueryTests {
    @Test func testInsertAndGetQuery() async throws {
        let db = try TestDB.inTempDir()
        try await db.insertFoo.execute(with: 1)
        
        let foos = try await db.selectFoos.execute()
        #expect(foos == [TestDB.Foo(bar: 1)])
        
        let foo = try await db.selectFoo.execute(with: 1)
        #expect(foo == TestDB.Foo(bar: 1))
    }
    
    @Test func selectManyWithEmptyDbReturnsEmpty() async throws {
        let db = try TestDB.inTempDir()
        let foos = try await db.selectFoos.execute()
        #expect(foos == [])
    }
    
    @Test func selectManyCanReturnManyItems() async throws {
        let db = try TestDB.inTempDir()
        try await db.insertFoo.execute(with: 1)
        try await db.insertFoo.execute(with: 2)
        let foos = try await db.selectFoos.execute()
        #expect(foos == [TestDB.Foo(bar: 1), TestDB.Foo(bar: 2)])
    }
    
    @Test func selectSingleWithEmptyDbReturnsNil() async throws {
        let db = try TestDB.inTempDir()
        let foo = try await db.selectFoo.execute(with: 1)
        #expect(foo == nil)
    }
    
    @Test func errorIsThrownWhenAttemptingToWriteToReadTx() async throws {
        let db = try TestDB.inTempDir()
        
        await #expect(throws: OtterError.cannotWriteInAReadTransaction) {
            _ = try await db.connection.begin(.read) { tx in
                try db.insertFoo.execute(with: 1, tx: tx)
            }
        }
    }
}
