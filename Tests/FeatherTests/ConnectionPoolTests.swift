//
//  ConnectionPoolTests.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import Testing
@testable import Feather

@Suite
struct ConnectionPoolTests {
    @Test func canOpenConnectionToPool() async throws {
        _ = try ConnectionPool(path: ":memory:", migrations: [])
    }

    @Test func poolRunsMigrationsOnInit() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: [
                "CREATE TABLE foo (bar INTEGER)"
            ]
        )
        
        let tx = try await pool.begin(.read)
        _ = try Statement("SELECT * FROM foo", transaction: tx)
    }
    
    @Test func poolReusesConnections() async throws {
        let pool = try ConnectionPool(
            path: ":memory:",
            limit: 1,
            migrations: [
                "CREATE TABLE foo (bar INTEGER)"
            ]
        )
        
        // Will hang indefinitely if a connection isnt recycled
        for _ in 0..<10 {
            let tx = try await pool.begin(.read)
            _ = try Statement("SELECT * FROM foo", transaction: tx)
        }
    }
}
