//
//  Connection.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import Collections
import SQLite3
import Foundation

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

/// Holds a raw SQLite database connection.
/// `@unchecked Sendable` Thread safety is managed by
/// the `ConnectionPool`
class Connection: @unchecked Sendable {
    let raw: OpaquePointer
    
    init(
        path: String,
        flags: Int32 = SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_NOMUTEX
            | SQLITE_OPEN_URI
    ) throws(FeatherError) {
        var raw: OpaquePointer?
        try throwing(sqlite3_open_v2(path, &raw, flags, nil))
        
        guard let raw else {
            throw .failedToOpenConnection(path: path)
        }
        
        self.raw = raw
    }
    
    func execute(sql: String) throws(FeatherError) {
        try throwing(sqlite3_exec(raw, sql, nil, nil, nil))
    }
    
    deinit {
        do {
            try throwing(sqlite3_close_v2(raw))
        } catch {
            assertionFailure("\(error)")
        }
    }
}

final class Signal: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.stream = stream
        self.continuation = continuation
    }

    func signal() {
        continuation.finish()
    }
    
    func wait() async {
        for await _ in stream {}
    }
}

public actor ConnectionPool: Sendable {
    private let path: String
    private var count: Int = 1
    private let limit: Int
    
    private var writeSignal: Signal?
    
    private let connectionStream: AsyncStream<Connection>
    private let connectionContinuation: AsyncStream<Connection>.Continuation
    
    public static let defaultLimit = 5
    
    public enum Begin {
        case read
        case write
    }
    
    public init(
        name: String,
        limit: Int = ConnectionPool.defaultLimit,
        migrations: [Migration]
    ) throws {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("\(name).sqlite")
        
        try self.init(path: url.absoluteString, limit: limit, migrations: migrations)
    }
    
    public init(
        path: String,
        limit: Int = ConnectionPool.defaultLimit,
        migrations: [Migration]
    ) throws {
        guard limit > 0 else {
            throw FeatherError.poolCannotHaveZeroConnections
        }
        
        self.path = path
        self.limit = limit
        let (connectionStream, connectionContinuation) = AsyncStream<Connection>.makeStream()
        self.connectionContinuation = connectionContinuation
        self.connectionStream = connectionStream
        
        let connection = try Connection(path: path)
        
        if limit > 1 {
            // Turn on WAL mode
            try connection.execute(sql: "PRAGMA journal_mode=WAL;")
        }
        
        let tx = try Transaction(
            connection: connection,
            pool: self,
            finalize: .rollback
        )
        
        try MigrationRunner.execute(migrations: migrations, tx: tx)
    }
    
    /// Gives the connection back to the pool.
    nonisolated func reclaim(
        connection: Connection,
        signal: Signal?
    ) {
        connectionContinuation.yield(connection)
        signal?.signal()
    }
    
    /// Starts a transaction.
    public func begin(
        _ begin: Begin,
        transaction: Transaction.Kind = .deferred
    ) async throws(FeatherError) -> sending Transaction {
        // Writes must be exclusive, make sure to wait on any pending writes.
        if begin == .write {
            if let writeSignal {
                await writeSignal.wait()
            }
        }
        
        // Helper function to create a transaction and set the
        // write signal if needed
        func tx(connection: Connection) throws(FeatherError) -> sending Transaction {
            assert(writeSignal == nil)
            writeSignal = begin == .write ? Signal() : nil
            return try Transaction(
                connection: connection,
                kind: transaction,
                pool: self,
                signal: writeSignal,
                finalize: begin == .write ? .rollback : .commit
            )
        }
        
        // Check if there is an available connection.
        // We could recieve a connection from the `for await`
        // below but we would have to eagerly create connections
        // even if one is all that is ever needed
        var connections = connectionStream.makeAsyncIterator()
        if let connection = await connections.next() {
            return try tx(connection: connection)
        }
        
        // Check if we have any capacity to create a new connection
        if count < limit {
            count += 1
            return try tx(connection: Connection(path: path))
        }
        
        // Wait for an available connection
        for await connection in connectionStream {
            return try tx(connection: connection)
        }
        
        // Can happen if the pool dies and the stream is closed
        // before the caller gets its transaction.
        throw .failedToGetConnection
    }
}

public enum FeatherError: Error {
    case failedToOpenConnection(path: String)
    case failedToInitializeStatement
    case columnIsNil(Int32)
    case noMoreColumns
    case queryReturnedNoValue
    case sqlite(SQLiteCode)
    case txNoLongerValid
    case failedToGetConnection
    case poolCannotHaveZeroConnections
    case alreadyCommited
}

public protocol RowDecodable {
    init(cursor: borrowing Cursor) throws(FeatherError)
}

extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public init(cursor: borrowing Cursor) throws(FeatherError) {
        var columns = cursor.indexedColumns()
        self = try columns.next()
    }
}

public struct Statement: ~Copyable {
    public let source: String
    let raw: OpaquePointer
    
    public init(
        _ source: String,
        transaction: borrowing Transaction
    ) throws(FeatherError) {
        self.source = source
        var raw: OpaquePointer?
        try throwing(sqlite3_prepare_v2(transaction.connection.raw, source, -1, &raw, nil))
        
        guard let raw else {
            throw .failedToInitializeStatement
        }
        
        self.raw = raw
    }
    
    public mutating func bind<Value: DatabasePrimitive>(
        value: Value,
        to index: Int32
    ) throws(FeatherError) {
        try value.bind(to: raw, at: index)
    }
    
    deinit {
        do {
            try throwing(sqlite3_finalize(raw))
        } catch {
            fatalError("Failed to finalize statement: \(error)")
        }
    }
}

public struct Cursor: ~Copyable {
    private let statement: Statement
    private var column: Int32 = 0
    
    public init(of statement: consuming Statement) {
        self.statement = statement
    }
    
    public func indexedColumns() -> IndexedColumns {
        return IndexedColumns(statement.raw)
    }
    
    public mutating func step() throws(FeatherError) -> Bool {
        let code = SQLiteCode(sqlite3_step(statement.raw))
        
        switch code {
        case .sqliteDone:
            return false
        case .sqliteRow:
            return true
        default:
            throw .sqlite(code)
        }
    }
}

public extension Cursor {
    /// A method of decoding columns. The fastest way
    /// to read the columns out of a select is in order.
    struct IndexedColumns: ~Copyable {
        @usableFromInline var raw: OpaquePointer
        @usableFromInline var column: Int32 = 0
        @usableFromInline let count: Int32
        
        init(_ raw: OpaquePointer) {
            self.raw = raw
            self.count = sqlite3_column_count(raw)
        }
        
        @inlinable public mutating func next<Value: DatabasePrimitive>() throws(FeatherError) -> Value {
            guard column < count else {
                throw .noMoreColumns
            }
            
            let value = try Value(from: raw, at: column)
            column += 1
            return value
        }
    }
}
