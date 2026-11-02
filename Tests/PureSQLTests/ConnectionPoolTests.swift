//
//  ConnectionPoolTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 11/9/24.
//

import Foundation
@testable import PureSQL
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
    
    @Test func withConnectionReclaimsConnectionOnError() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: ["CREATE TABLE foo (bar INTEGER)"]
        )
        struct Err: Error {}
        
        // Will hang indefinitely if the connection and write
        // lock arent given back after the error
        for _ in 0..<10 {
            await #expect(throws: Err.self) {
                try await pool.withConnection(isWrite: true) { _ in throw Err() }
            }
        }
        
        try await pool.begin(.write) { tx in
            try tx.execute(sql: "INSERT INTO foo (bar) VALUES (1)")
        }
    }
    
    @Test func modificationsAreRolledBackOnError() async throws {
        let db = try TestDB.inMemory(adapters: TestDB.Adapters())
        struct Err: Error {}
        
        try? await db.connection.begin(.write) { tx in
            try db.insertFoo.execute(1, tx: tx)
            throw Err()
        }
        
        let foos = try await db.selectFoos.execute()
        #expect(foos.isEmpty)
    }
}
