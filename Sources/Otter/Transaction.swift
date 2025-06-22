//
//  Transaction.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

/// A SQLite transaction.
public struct Transaction: ~Copyable {
    let connection: SQLiteConnection
    let kind: Kind
    let behavior: Behavior
    
    public enum Behavior: String, Sendable {
        case deferred = "DEFERRED"
        case immediate = "IMMEDIATE"
        case exclusive = "EXCLUSIVE"
    }
    
    public enum Kind: Int, Sendable, Comparable {
        case read
        case write
        
        public static func < (lhs: Kind, rhs: Kind) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    init(
        connection: SQLiteConnection,
        kind: Kind,
        behavior: Behavior = .deferred
    ) throws(OtterError) {
        self.connection = connection
        self.kind = kind
        self.behavior = behavior
        try connection.execute(sql: "BEGIN \(behavior.rawValue) TRANSACTION;")
    }
    
    /// Executes the raw SQL
    public func execute(sql: String) throws(OtterError) {
        try connection.execute(sql: sql)
    }
    
    /// Commits any changes to the db
    public consuming func commit() throws(OtterError) {
        try connection.execute(sql: "COMMIT")
    }
    
    /// Should be called on error. If it is a read then it will just commit
    /// but writes will be rolled back.
    public consuming func commitOrRollback() throws(OtterError) {
        switch kind {
        case .read:
            try connection.execute(sql: "COMMIT")
        case .write:
            try connection.execute(sql: "ROLLBACK")
        }
    }
}
