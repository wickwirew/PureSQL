//
//  Migration.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public struct MigrationRunner {
    static let migrationTableName = "__featherMigrations"
    
    public static func execute(migrations: [String], pool: ConnectionPool) async throws {
        let tx = try await pool.begin(.write)
        try execute(migrations: migrations, tx: tx)
        try tx.commit()
    }
    
    public static func execute(migrations: [String], tx: borrowing Transaction) throws {
        try createTableIfNeeded(tx: tx)
        
        let lastMigration = try LastMigrationQuery()
            .replaceNil(with: 0)
            .execute(with: (), tx: tx)
        
        let pendingMigrations = migrations.enumerated()
            .map { (number: $0.offset + 1, migration: $0.element) }
            .filter { $0.number > lastMigration }
            .sorted { $0.number < $1.number }
        
        for (number, migration) in pendingMigrations {
            try execute(migration: migration, number: number, tx: tx)
        }
    }
    
    static func createTableIfNeeded(tx: borrowing Transaction) throws(FeatherError) {
        try tx.execute(sql: """
        CREATE TABLE IF NOT EXISTS \(migrationTableName)(
            number INTEGER PRIMARY KEY
        ) STRICT;
        """)
    }
    
    static func execute(migration: String, number: Int, tx: borrowing Transaction) throws {
        try tx.execute(sql: migration)
        try InsertMigrationQuery().execute(with: number, tx: tx)
    }

    struct LastMigrationQuery: DatabaseQuery {
        var transactionKind: TransactionKind { .read }
        func execute(
            with _: (),
            tx: borrowing Transaction
        ) throws -> Int? {
            let statement = try Statement(in: tx) {
                "SELECT MAX(number) FROM \(MigrationRunner.migrationTableName)"
            }
            
            return try statement.fetchOne(of: Int.self)
        }
    }
    
    struct InsertMigrationQuery: DatabaseQuery {
        var transactionKind: TransactionKind { .write }
        func execute(
            with input: Int,
            tx: borrowing Transaction
        ) throws {
            let statement = try Statement(in: tx) {
                "INSERT INTO \(MigrationRunner.migrationTableName) (number) VALUES (?)"
            } bind: { statement in
                try statement.bind(value: input, to: 1)
            }
            
            _ = try statement.step()
        }
    }
}
