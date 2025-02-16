//
//  Migration.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public struct Migration {
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
        try await tx.commit()
    }
    
    public static func execute(migrations: [Migration], tx: Transaction) throws {
        let lastMigration = try GetLastMigrationNumber().execute(in: tx)
        
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
        try InsertMigration().execute(with: migration.number, in: tx)
    }
    
    struct GetLastMigrationNumber: DatabaseQuery {
        typealias Input = ()
        typealias Output = Int
        typealias Context = Transaction
        
        func statement(
            in transaction: Transaction,
            with input: ()
        ) throws(FeatherError) -> Statement {
            return try Statement(
                "SELECT MAX(number) FROM migrations",
                transaction: transaction
            )
        }
    }
    
    struct InsertMigration: DatabaseQuery {
        typealias Input = Int
        typealias Output = ()
        typealias Context = Transaction
        
        func statement(
            in transaction: Transaction,
            with input: Int
        ) throws(FeatherError) -> Statement {
            var statement = try Statement(
                "INSERT INTO \(MigrationRunner.migrationTableName) (number) VALUES (?)",
                transaction: transaction
            )
            try statement.bind(value: input, to: 0)
            return statement
        }
    }
}
