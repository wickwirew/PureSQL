//
//  ConnectionPool.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import Foundation

public enum DatabaseLocation {
    case inMemory
    case applicationDirectory(name: String)
    case path(String)
}

public actor ConnectionPool: Sendable {
    private let path: String
    private var count: Int = 1
    private let limit: Int
    private let observer = DatabaseObserver()
    
    private var writeLock = Lock()
    
    private let connectionStream: AsyncStream<Connection>
    private let connectionContinuation: AsyncStream<Connection>.Continuation
    
    public static let defaultLimit = 5
    
    public init(
        name: String,
        limit: Int = ConnectionPool.defaultLimit,
        migrations: [String]
    ) throws {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("\(name).sqlite")
        
        try self.init(path: url.absoluteString, limit: limit, migrations: migrations)
    }
    
    public init(
        path: String,
        limit: Int = ConnectionPool.defaultLimit,
        migrations: [String]
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
        self.observer.installHooks(into: connection)
        
        // Turn on WAL mode
        try connection.execute(sql: "PRAGMA journal_mode=WAL;")
        
        let tx = try Transaction(
            connection: connection,
            kind: .write,
            pool: self
        )
        
        try MigrationRunner.execute(migrations: migrations, tx: tx)
        try tx.commit()
    }
    
    /// Gives the connection back to the pool.
    nonisolated func reclaim(
        connection: Connection,
        txKind: TransactionKind
    ) {
        connectionContinuation.yield(connection)
        
        if txKind == .write {
            // TODO: Find a better way to do this.
            Task { await writeLock.unlock() }
        }
    }
    
    /// Starts a transaction.
    public func begin(
        _ kind: TransactionKind
    ) async throws(FeatherError) -> sending Transaction {
        // Writes must be exclusive, make sure to wait on any pending writes.
        if kind == .write {
            await writeLock.lock()
        }
        
        // Helper function to create a transaction and set the
        // write signal if needed
        func tx(connection: Connection) throws(FeatherError) -> sending Transaction {
            return try Transaction(
                connection: connection,
                kind: kind,
                pool: self
            )
        }
        
        // Check if there is an available connection.
        // We could recieve a connection from the `for await`
        // below but we would have to eagerly create connections
        // even if one is all that is ever needed
//        var connections = connectionStream.makeAsyncIterator()
//        if let connection = await connections.next() {
//            return try tx(connection: connection)
//        }
        
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
    
    func observe(observation: @Sendable @escaping () -> Void) -> DatabaseObserver.Token {
        return observer.observe { _ in observation() }
    }
}
