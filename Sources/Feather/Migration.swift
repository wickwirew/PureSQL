//
//  Migration.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public struct Migration: Sendable {
    public let number: Int
    public let sql: String
    
    public init(number: Int, sql: String) {
        self.number = number
        self.sql = sql
    }
}

public struct MigrationRunner {
    static let migrationTableName = "__featherMigrations"
    
    public static func execute(migrations: [Migration], pool: ConnectionPool) async throws {
        let tx = try await pool.begin(.write)
        try execute(migrations: migrations, tx: tx)
        try tx.commit()
    }
    
    public static func execute(migrations: [Migration], tx: Transaction) throws {
        try createTableIfNeeded(tx: tx)
        
        let lastMigration = try lastMigration.execute(with: (), tx: tx)
        
        let pendingMigrations = migrations
            .filter { $0.number > lastMigration }
            .sorted { $0.number < $1.number }
        
        for migration in pendingMigrations {
            try execute(migration: migration, tx: tx)
        }
    }
    
    static func createTableIfNeeded(tx: Transaction) throws(FeatherError) {
        try tx.execute(sql: """
        CREATE TABLE IF NOT EXISTS \(migrationTableName)(
            number INTEGER PRIMARY KEY
        ) STRICT;
        """)
    }
    
    static func execute(migration: Migration, tx: Transaction) throws {
        try tx.execute(sql: migration.sql)
        try insertMigration.execute(with: migration.number, tx: tx)
    }
    
    private static var lastMigration: DatabaseQuery<(), Int> {
        return DatabaseQuery(.read) { _, transaction in
            try Statement(in: transaction) {
                "SELECT MAX(number) FROM \(MigrationRunner.migrationTableName)"
            }
        }
    }
    
    private static var insertMigration: DatabaseQuery<Int, ()> {
        return DatabaseQuery(.write) { input, transaction in
            try Statement(in: transaction) {
                "INSERT INTO \(MigrationRunner.migrationTableName) (number) VALUES (?)"
            } bind: { statement in
                try statement.bind(value: input, to: 1)
            }
        }
    }
}
