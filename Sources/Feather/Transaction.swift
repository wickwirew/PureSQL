//
//  Transaction.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

/// This cannot be a struct that suppresses `Copyable`
/// unfortunately. Associated types cannot suppress
/// it which breaks the `Query` API. Maybe a future thing.
public final class Transaction {
    let connection: Connection
    let kind: Kind
    let signal: Signal?
    let finalize: Finalize
    private var didCommit = false
    private let pool: ConnectionPool
    
    public enum Kind: String, Sendable {
        case deferred = "DEFERRED"
        case immediate = "IMMEDIATE"
        case exclusive = "EXCLUSIVE"
    }
    
    public enum Finalize: String, Sendable {
        case commit = "COMMIT"
        case rollback = "ROLLBACK"
    }
    
    init(
        connection: Connection,
        kind: Kind = .deferred,
        pool: ConnectionPool,
        signal: Signal? = nil,
        finalize: Finalize
    ) throws(FeatherError) {
        self.connection = connection
        self.kind = kind
        self.pool = pool
        self.signal = signal
        self.finalize = finalize
        try connection.execute(sql: "BEGIN \(kind.rawValue) TRANSACTION;")
    }
    
    public func execute(sql: String) throws(FeatherError) {
        try connection.execute(sql: sql)
    }
    
    public consuming func commit() async throws(FeatherError) {
        guard !didCommit else {
            throw .alreadyCommited
        }
        
        didCommit = true
        try connection.execute(sql: "COMMIT;")
        pool.reclaim(connection: connection, signal: signal)
    }
    
    deinit {
        if !didCommit {
            do {
                try connection.execute(sql: "\(finalize.rawValue);")
            } catch {
                assertionFailure("Failed to \(finalize.rawValue): \(error)")
            }
            
            pool.reclaim(connection: connection, signal: signal)
        }
    }
}
