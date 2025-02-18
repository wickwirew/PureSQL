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
                try connection.execute(sql: "\(finalize.rawValue);")
            } catch {
                assertionFailure("Failed to \(finalize.rawValue): \(error)")
            }
        }
        
        pool.reclaim(connection: connection, signal: signal)
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
