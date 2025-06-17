//
//  ConnectionPool.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import Foundation

/// Manages a pool of connections to the database. Will automatically
/// Create, get, or wait for a connection from the `begin` call.
///
/// `WAL` mode is turned on automatically allowing for concurrent reads
/// while a write is happening. It will automatically make any other
/// write transactions wait if one is going on without blocking using
/// swift's async await.
public actor ConnectionPool: Sendable {
    /// The path to the database
    private let path: String
    /// The current connection count. This is not the available count
    /// but how many we have created
    private var count: Int = 1
    /// The maximum number of connections we can create
    private let limit: Int
    /// Any connections available for use
    private var availableConnections: [SQLiteConnection]
    /// Any caller waiting for a connection
    private var waitingForConnection: [WaiterContinuation] = []
    /// A lock to synchronize writes.
    private var writeLock = Lock()
    /// Manages alerting any subscribers of any database changes.
    private nonisolated let observer = DatabaseObserver()
    
    typealias WaiterContinuation = CheckedContinuation<SQLiteConnection, Never>
    
    public init(
        path: String,
        limit: Int,
        migrations: [String]
    ) throws {
        guard limit > 0 else {
            throw FeatherError.poolCannotHaveZeroConnections
        }
        
        self.path = path
        self.limit = limit
        
        let connection = try SQLiteConnection(path: path)
        self.observer.installHooks(into: connection)
        
        // Turn on WAL mode
        try connection.execute(sql: "PRAGMA journal_mode=WAL;")
        
        let tx = try Transaction(connection: connection, kind: .write)
        try MigrationRunner.execute(migrations: migrations, tx: tx)
        try tx.commit()
        
        self.availableConnections = [connection]
    }
    
    /// Whether or not we have created all the connections we are allowed too
    var isAtConnectionLimit: Bool {
        return count >= limit
    }
    
    /// Starts a transaction.
    private func begin(
        _ kind: Transaction.Kind
    ) async throws(FeatherError) -> sending Transaction {
        // Writes must be exclusive, make sure to wait on any pending writes.
        if kind == .write {
            await writeLock.lock()
        }
        
        return try await Transaction(connection: getConnection(), kind: kind)
    }
    
    /// Gives the connection back to the pool.
    private func reclaim(tx: borrowing Transaction) async {
        availableConnections.append(tx.connection)
        alertAnyWaitersOfAvailableConnection()
        
        if tx.kind == .write {
            await writeLock.unlock()
        }
    }
    
    /// Will get, wait or create a connection to the database
    private func getConnection() async throws(FeatherError) -> SQLiteConnection {
        guard availableConnections.isEmpty else {
            // Have an available connection, just use it
            return availableConnections.removeLast()
        }
        
        guard !isAtConnectionLimit else {
            // At the limit, need to wait for one
            return await withCheckedContinuation { continuation in
                waitingForConnection.append(continuation)
            }
        }
        
        return try newConnection()
    }
    
    /// Initializes a new SQL connection
    private func newConnection() throws(FeatherError) -> SQLiteConnection {
        assert(count < limit)
        count += 1
        let connection = try SQLiteConnection(path: path)
        observer.installHooks(into: connection)
        return connection
    }
    
    /// Called when we receive a connection back into the pool
    /// and we need to alert anybody waiting for one.
    private func alertAnyWaitersOfAvailableConnection() {
        guard !waitingForConnection.isEmpty, !availableConnections.isEmpty else { return }
        let waiter = waitingForConnection.removeFirst()
        let connection = availableConnections.removeFirst()
        waiter.resume(with: .success(connection))
    }
}

extension ConnectionPool: Connection {
    public nonisolated func observe(subscriber: any DatabaseSubscriber) {
        observer.subscribe(subscriber: subscriber)
    }
    
    public nonisolated func cancel(subscriber: any DatabaseSubscriber) {
        observer.cancel(subscriber: subscriber)
    }
    
    /// Starts a transaction.
    public func begin<Output>(
        _ kind: Transaction.Kind,
        execute: (borrowing Transaction) throws -> Output
    ) async throws -> Output {
        let tx = try await begin(kind)
        
        // The `Result` wrapper seems weird, but allows us to keep
        // tx functions consuming. Cause we cannot call `commit` in
        // the `do` and on failure call `rollback` since it would
        // have been consumed in the `commit`.
        //
        // Keeping them is consuming is nice since it stops callers
        // from calling `commit` manually since its borrowed
        let result = Result {
            try execute(tx)
        }
        
        await reclaim(tx: tx)
        
        switch result {
        case .success(let output):
            try tx.commit()
            observer.didCommit()
            return output
        case .failure(let error):
            try tx.commitOrRollback()
            throw error
        }
    }
}
