//
//  Migration.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/16/25.
//

/// Executes the migrations and ensures it is up to date.
enum MigrationRunner {
    static let migrationTableName = "__puresqlMigration"

    static func execute(migrations: [String], connection: SQLiteConnection) throws {
        let previouslyRunMigrations = try runMigrations(connection: connection)
        let lastMigration = previouslyRunMigrations.last ?? Int.min
        
        let pendingMigrations = migrations.enumerated()
            .map { (number: $0.offset, migration: $0.element) }
            .filter { $0.number > lastMigration }
        
        for (number, migration) in pendingMigrations {
            // Run each migration in it's own transaction.
            let tx = try Transaction(connection: connection, kind: .write)
            
            let result = Result {
                try execute(migration: migration, number: number, tx: tx)
            }
            
            switch result {
            case .success:
                try tx.commit()
            case .failure(let error):
                try tx.commitOrRollback()
                throw error
            }
        }
    }
    
    /// Executes the migration, if the `number` exists it will be
    /// recorded in the migrations table.
    private static func execute(
        migration: String,
        number: Int?,
        tx: borrowing Transaction
    ) throws {
        try tx.execute(sql: migration)
        
        if let number {
            try insertMigration(version: number, tx: tx)
        }
    }
    
    /// Creates the migrations table and gets the last migration that ran.
    private static func runMigrations(connection: SQLiteConnection) throws -> [Int] {
        let tx = try Transaction(connection: connection, kind: .write)
        
        // Create the migration table if need be.
        try tx.execute(sql: """
        CREATE TABLE IF NOT EXISTS \(migrationTableName)(
            number INTEGER PRIMARY KEY
        ) STRICT;
        """)
        
        let statement = try Statement(in: tx) {
            "SELECT * FROM \(MigrationRunner.migrationTableName) ORDER BY number ASC"
        }
        
        let migrations: [Int] = try statement.fetchAll()
        try tx.commit()
        return migrations
    }
    
    private static func insertMigration(version: Int, tx: borrowing Transaction) throws {
        let statement = try Statement(in: tx) {
            "INSERT INTO \(MigrationRunner.migrationTableName) (number) VALUES (?)"
        } bind: { statement in
            try statement.bind(value: version, to: 1)
        }
        
        _ = try statement.step()
    }
}
