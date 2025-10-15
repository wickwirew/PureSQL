//
//  QueryTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/18/25.
//

import Testing

@testable import PureSQL

@Suite
struct QueryTests {
    @Test func testInsertAndGetQuery() async throws {
        let db = try TestDB.inTempDir()
        try await db.insertFoo.execute(1)
        
        let foos = try await db.selectFoos.execute()
        #expect(foos == [TestDB.Foo(bar: 1)])
        
        let foo = try await db.selectFoo.execute(1)
        #expect(foo == TestDB.Foo(bar: 1))
    }
    
    @Test func selectManyWithEmptyDbReturnsEmpty() async throws {
        let db = try TestDB.inTempDir()
        let foos = try await db.selectFoos.execute()
        #expect(foos == [])
    }
    
    @Test func selectManyCanReturnManyItems() async throws {
        let db = try TestDB.inTempDir()
        try await db.insertFoo.execute(1)
        try await db.insertFoo.execute(2)
        let foos = try await db.selectFoos.execute()
        #expect(foos == [TestDB.Foo(bar: 1), TestDB.Foo(bar: 2)])
    }
    
    @Test func selectSingleWithEmptyDbReturnsNil() async throws {
        let db = try TestDB.inTempDir()
        let foo = try await db.selectFoo.execute(1)
        #expect(foo == nil)
    }
    
    @Test func errorIsThrownWhenAttemptingToWriteToReadTx() async throws {
        let db = try TestDB.inTempDir()
        
        await #expect(throws: SQLError.cannotWriteInAReadTransaction) {
            _ = try await db.connection.begin(.read) { tx in
                try db.insertFoo.execute(1, tx: tx)
            }
        }
    }
    
    @Test func optionallyIncludedEmbeddedJoin_Exists() async throws {
        let db = try TestDB.inMemory()
        
        try await db.insertFoo.execute(1)
        try await db.insertBaz.execute(1)
        
        let result = try await db.selectFooAndBaz.execute()
        
        #expect(result == [.init(foo: .init(bar: 1), baz: .init(qux: 1))])
    }
    
    @Test func optionallyIncludedEmbeddedJoin_DoesNotExists() async throws {
        let db = try TestDB.inMemory()
        
        try await db.insertFoo.execute(1)
        
        let result = try await db.selectFooAndBaz.execute()
        
        #expect(result == [.init(foo: .init(bar: 1), baz: nil)])
    }
    
    @Test func arrayInput() async throws {
        let db = try TestDB.inMemory()
        
        try await db.insertFoo.execute(1)
        try await db.insertFoo.execute(2)
        try await db.insertFoo.execute(3)
        
        let oneAndThree = try await db.selectFooWithIds.execute([1, 3])
        #expect(oneAndThree == [.init(bar: 1), .init(bar: 3)])
        
        let one = try await db.selectFooWithIds.execute([1])
        #expect(one == [.init(bar: 1)])
        
        let all = try await db.selectFooWithIds.execute([1, 2, 3])
        #expect(all == [.init(bar: 1), .init(bar: 2), .init(bar: 3)])
        
        let none = try await db.selectFooWithIds.execute([])
        #expect(none == [])
    }
}
