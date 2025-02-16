//
//  ConnectionPool.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

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
