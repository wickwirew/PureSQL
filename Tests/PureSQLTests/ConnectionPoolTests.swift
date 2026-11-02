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
    
    @Test func failedBeginReclaimsConnection() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: ["CREATE TABLE foo (bar INTEGER)"]
        )
        
        // Leaves a transaction open so the next `BEGIN` fails
        try await pool.withConnection(isWrite: true) { conn in
            try conn.execute(sql: "BEGIN")
        }
        
        // Will hang indefinitely if the connection and write
        // lock arent given back after the failed `BEGIN`
        for _ in 0..<10 {
            await #expect(throws: SQLError.self) {
                try await pool.begin(.write) { _ in }
            }
        }
        
        try await pool.withConnection(isWrite: true) { conn in
            try conn.execute(sql: "COMMIT")
        }
        
        try await pool.begin(.write) { tx in
            try tx.execute(sql: "INSERT INTO foo (bar) VALUES (1)")
        }
    }
    
    @Test func failedCommitRollsBackAndLeavesConnectionUsable() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: ["""
            CREATE TABLE parent (id INTEGER PRIMARY KEY);
            CREATE TABLE child (
                parent INTEGER NOT NULL REFERENCES parent (id) DEFERRABLE INITIALLY DEFERRED
            );
            """]
        )
        
        // The deferred foreign key is only checked at `COMMIT`, which
        // fails and leaves the transaction open
        await #expect(throws: SQLError.self) {
            try await pool.begin(.write) { tx in
                try tx.execute(sql: "INSERT INTO child (parent) VALUES (1)")
            }
        }
        
        try await pool.begin(.write) { tx in
            try tx.execute(sql: "INSERT INTO parent (id) VALUES (1)")
        }
        
        let children = try await pool.begin(.read) { tx in
            try Statement("SELECT count(*) FROM child", transaction: tx).fetchOne(of: Int.self)
        }
        #expect(children == 0)
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
