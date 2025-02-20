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
        try connection.execute(sql: "COMMIT;")
    }
    
    deinit {
        if !didCommit {
            do {
                switch kind {
                case .read:
                    try connection.execute(sql: "COMMIT;")
                case .write:
                    try connection.execute(sql: "ROLLBACK;")
                }
            } catch {
                assertionFailure("Failed to commit or rollback")
            }
        }
        
        pool.reclaim(connection: connection, txKind: kind)
    }
}

extension Transaction {
    public func fetchMany<Element>(
        of type: Element.Type,
        statement: consuming Statement
    ) throws(FeatherError) -> [Element] where Element: RowDecodable {
        var cursor = Cursor(of: statement)
        var result: [Element] = []
        
        while try cursor.step() {
            try result.append(Element(cursor: cursor))
        }
        
        return result
    }
    
    public func fetchOne<Element>(
        of type: Element.Type,
        statement: consuming Statement
    ) throws(FeatherError) -> Element where Element: RowDecodable {
        var cursor = Cursor(of: statement)
        
        guard try cursor.step() else {
            throw .queryReturnedNoValue
        }
        
        return try Element(cursor: cursor)
    }
    
    public func execute(
        statement: consuming Statement
    ) throws(FeatherError) {
        var cursor = Cursor(of: statement)
        _ = try cursor.step()
    }

    public func fetchMany<Element>(
        of type: Element.Type,
        sql: String
    ) throws(FeatherError) -> [Element] where Element: RowDecodable {
        let statement = try Statement(sql, transaction: self)
        return try fetchMany(of: Element.self, statement: statement)
    }
    
    public func fetchOne<Element>(
        of type: Element.Type,
        sql: String
    ) throws(FeatherError) -> Element? where Element: RowDecodable {
        let statement = try Statement(sql, transaction: self)
        return try fetchOne(of: Element.self, statement: statement)
    }
}

public enum TransactionKind: Sendable {
    case read
    case write
}

public protocol TransactionProvider: Actor {
    func begin(
        _ kind: TransactionKind
    ) async throws -> sending Transaction
}
