//
//  ConnectionPoolTests.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import Foundation
import Testing
@testable import Feather

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
}
