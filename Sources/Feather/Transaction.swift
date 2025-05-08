//
//  Transaction.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

/// A SQLite transaction.
public struct Transaction: ~Copyable {
    let connection: SQLiteConnection
    let kind: TransactionKind
    let behavior: Behavior
    private var didCommit = false
    private let pool: ConnectionPool?
    
    public enum Behavior: String, Sendable {
        case deferred = "DEFERRED"
        case immediate = "IMMEDIATE"
        case exclusive = "EXCLUSIVE"
    }
    
    init(
        connection: SQLiteConnection,
        kind: TransactionKind,
        behavior: Behavior = .deferred,
        pool: ConnectionPool?
    ) throws(FeatherError) {
        self.connection = connection
        self.kind = kind
        self.behavior = behavior
        self.pool = pool
        try connection.execute(sql: "BEGIN \(behavior.rawValue) TRANSACTION;")
    }
    
    public func execute(sql: String) throws(FeatherError) {
        try connection.execute(sql: sql)
    }
    
    public consuming func commit() async throws(FeatherError) {
        guard !didCommit else {
            // This should never happen since its ~Copyable in a consuming
            // function but cant hurt to double check
            throw .alreadyCommited
        }
        
        didCommit = true
        try connection.execute(sql: "COMMIT")
        
        pool?.didCommit(transaction: self)
        
        await pool?.reclaim(connection: connection, txKind: kind)
    }
    
    consuming func commitWithoutReclaim() throws(FeatherError) {
        guard !didCommit else {
            throw .alreadyCommited
        }
        
        didCommit = true
        try connection.execute(sql: "COMMIT")
    }
    
    deinit {
        guard didCommit else { return }
        
        do {
            // Did not commit, need to either auto commit or rollback the changes.
            switch kind {
            case .read:
                try connection.execute(sql: "COMMIT")
            case .write:
                try connection.execute(sql: "ROLLBACK")
            }
            
            // Feels dirty having this task here but it cannot be done
            // in a synchronous way...
            Task { [pool, connection, kind] in
                await pool?.reclaim(connection: connection, txKind: kind)
            }
        } catch {
            assertionFailure("Failed to commit or rollback")
        }
    }
}

public enum TransactionKind: Int, Sendable {
    case read
    case write
}

extension TransactionKind: Comparable {
    public static func < (lhs: TransactionKind, rhs: TransactionKind) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
