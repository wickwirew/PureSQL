//
//  MigrationRunnerTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/24/25.
//

import Testing

@testable import PureSQL

@Suite
struct MigrationRunnerTests: ~Copyable {
    let connection = try! SQLiteConnection(path: ":memory:")
    
    @Test func migrationTableIsCreated() async throws {
        try MigrationRunner.execute(migrations: [], connection: connection)
        #expect(try runMigrations().isEmpty)
        let tableNames = try tableNames()
        #expect(tableNames.contains(MigrationRunner.migrationTableName))
    }
    
    @Test func userTableIsCreated() async throws {
        try MigrationRunner.execute(migrations: ["CREATE TABLE foo (bar INTEGER)"], connection: connection)
        #expect(try runMigrations() == [0])
        let tableNames = try tableNames()
        #expect(tableNames.contains("foo"))
    }
    
    @Test func migrationFailsWithErrorIfMigrationHasAnError() async throws {
        #expect(throws: SQLError.self) {
            try MigrationRunner.execute(migrations: [
                "CREATE TABLE foo (bar INTEGER)",
                "CREATE TABLE foo (bar INTEGER)"
            ], connection: connection)
        }
    }
    
    @Test func migrationsAreRunInOrder() async throws {
        try MigrationRunner.execute(
            migrations: [
                "CREATE TABLE migrationOrder (value TEXT)",
                "INSERT INTO migrationOrder (value) VALUES ('first')",
                "UPDATE migrationOrder SET value = value || ', second'",
                "UPDATE migrationOrder SET value = value || ', third'",
            ],
            connection: connection
        )

        let value: String? = try query("SELECT * FROM migrationOrder") { try $0.fetchOne() }
        #expect(value == "first, second, third")
    }
    
    @Test func migrationsAreRunIncrementally() async throws {
        var migrations = ["CREATE TABLE foo (value TEXT)"]
        
        try MigrationRunner.execute(
            migrations: migrations,
            connection: connection
        )
        
        migrations.append("CREATE TABLE bar (value TEXT)")
        
        try MigrationRunner.execute(
            migrations: migrations,
            connection: connection
        )
        
        // Run again with no new migrations
        try MigrationRunner.execute(
            migrations: migrations,
            connection: connection
        )

        let _: String? = try query("SELECT * FROM foo") { try $0.fetchOne() }
        let _: String? = try query("SELECT * FROM bar") { try $0.fetchOne() }
    }
    
    @Test func failedMigrationRollsbackChanges() async throws {
        #expect(throws: SQLError.self) {
            try MigrationRunner.execute(
                migrations: [
                    """
                    CREATE TABLE foo (bar INTEGER);
                    CREATE TABLE foo (bar INTEGER); -- Fails
                    """
                ],
                connection: connection
            )
        }

        let tables = try tableNames()
        #expect(!tables.contains("foo"))
    }
    
    @Test func migrationsBeforeAFailureAreCommited() async throws {
        #expect(throws: SQLError.self) {
            try MigrationRunner.execute(
                migrations: [
                    "CREATE TABLE foo (bar INTEGER);",
                    "CREATE TABLE foo (bar INTEGER); -- Fails"
                ],
                connection: connection
            )
        }

        let tables = try tableNames()
        #expect(tables.contains("foo"))
    }
    
    private func runMigrations() throws -> [Int] {
        return try query("SELECT * FROM \(MigrationRunner.migrationTableName) ORDER BY number ASC") { try $0.fetchAll() }
    }
    
    private func tableNames() throws -> Set<String> {
        return try query("SELECT name FROM sqlite_master") { try Set($0.fetchAll()) }
    }
    
    private func query<Output>(
        _ stmt: String,
        execute: (consuming Statement) throws -> Output
    ) throws -> Output {
        let tx = try Transaction(connection: connection, kind: .read)
        let statement = try Statement(in: tx) { stmt }
        let result = try execute(statement)
        try tx.commit()
        return result
    }
}
