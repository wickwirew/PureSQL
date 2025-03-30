//
//  Transaction.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public struct Transaction: ~Copyable {
    let connection: Connection
    let kind: TransactionKind
    let behavior: Behavior
    private var didCommit = false
    private let pool: ConnectionPool
    
    public enum Behavior: String, Sendable {
        case deferred = "DEFERRED"
        case immediate = "IMMEDIATE"
        case exclusive = "EXCLUSIVE"
    }
    
    init(
        connection: Connection,
        kind: TransactionKind,
        behavior: Behavior = .deferred,
        pool: ConnectionPool
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
    
    public consuming func commit() throws(FeatherError) {
        guard !didCommit else {
            throw .alreadyCommited
        }
        
        didCommit = true
        try connection.execute(sql: "COMMIT")
        
        pool.didCommit(transaction: self)
    }
    
    deinit {
        if !didCommit {
            do {
                switch kind {
                case .read:
                    try connection.execute(sql: "COMMIT")
                case .write:
                    try connection.execute(sql: "ROLLBACK")
                }
            } catch {
                assertionFailure("Failed to commit or rollback")
            }
        }
        
        pool.reclaim(connection: connection, txKind: kind)
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
