//
//  ConnectionPoolTests.swift
//  Otter
//
//  Created by Wes Wickwire on 11/9/24.
//

import Foundation
@testable import Otter
import Testing

@Suite
struct ConnectionPoolTests {
    @Test func canOpenConnectionToPool() async throws {
        _ = try ConnectionPool(path: ":memory:", limit: 1, migrations: [])
    }

    @Test func poolRunsMigrationsOnInit() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: ["CREATE TABLE foo (bar INTEGER)"]
        )
        
        try await pool.begin(.read) { tx in
            _ = try Statement("SELECT * FROM foo", transaction: tx)
        }
    }
    
    @Test func poolReclaimsConnectionWhenFinished() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: ["CREATE TABLE foo (bar INTEGER)"]
        )
        
        // Will hang indefinitely if a connection isnt recycled
        // since its a single connection
        for _ in 0..<10 {
            try await pool.begin(.read) { tx in
                _ = try Statement("SELECT * FROM foo", transaction: tx)
            }
        }
    }
    
    @Test func modificationsAreRolledBackOnError() async throws {
        let db = try TestDB.inMemory()
        struct Err: Error {}
        
        try? await db.connection.begin(.write) { tx in
            try db.insertFoo.execute(with: 1, tx: tx)
            throw Err()
        }
        
        let foos = try await db.selectFoos.execute()
        #expect(foos.isEmpty)
    }
}
