//
//  ConnectionPool.swift
//  PureSQL
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
    private var availableConnections: [RawConnection]
    /// Any caller waiting for a connection
    private var waitingForConnection: [WaiterContinuation] = []
    /// A lock to synchronize writes.
    private var writeLock = Lock()
    /// Manages alerting any subscribers of any database changes.
    private nonisolated let observer = DatabaseObserver()
    
    typealias WaiterContinuation = CheckedContinuation<RawConnection, Never>
    
    public init(
        path: String,
        limit: Int,
        migrations: [String]
    ) throws {
        guard limit > 0 else {
            throw SQLError.poolCannotHaveZeroConnections
        }
        
        self.path = path
        self.limit = limit
        
        let connection = try SQLiteConnection(path: path)
        self.observer.installHooks(into: connection)
        
        // Turn on WAL mode
        try connection.execute(sql: "PRAGMA journal_mode=WAL;")
        try MigrationRunner.execute(migrations: migrations, connection: connection)
        self.availableConnections = [connection]
    }

    /// Whether or not we have created all the connections we are allowed too
    var isAtConnectionLimit: Bool {
        return count >= limit
    }
    
    /// Starts a transaction.
    private func begin(
        _ kind: Transaction.Kind
    ) async throws(SQLError) -> sending Transaction {
        // Writes must be exclusive, make sure to wait on any pending writes.
        if kind == .write {
            await writeLock.lock()
        }
        
        return try await Transaction(connection: getConnection(), kind: kind)
    }
    
    /// Gives the connection back to the pool.
    private func reclaim(connection: RawConnection, kind: Transaction.Kind) async {
        availableConnections.append(connection)
        alertAnyWaitersOfAvailableConnection()
        
        if kind == .write {
            await writeLock.unlock()
        }
    }
    
    /// Will get, wait or create a connection to the database
    private func getConnection() async throws(SQLError) -> RawConnection {
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
    private func newConnection() throws(SQLError) -> SQLiteConnection {
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
        // I think its handing a connection off to a cancelled task?
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
    public nonisolated func begin<Output: Sendable>(
        _ kind: Transaction.Kind,
        execute: @Sendable (borrowing Transaction) throws -> Output
    ) async throws -> Output {
        try await beginNoCommit(kind) { tx in
            // The `Result` wrapper seems weird, but allows us to keep
            // tx functions consuming. Cause we cannot call `commit` in
            // the `do` and on failure call `rollback` since it would
            // have been consumed in the `commit`.
            //
            // Keeping them is consuming is nice since it stops callers
            // from calling `commit` manually since its borrowed
            let result = Result {
                try Task.checkCancellation()
                return try execute(tx)
            }
            
            switch result {
            case let .success(output):
                try tx.commit()
                observer.didCommit()
                return output
            case let .failure(error):
                try tx.commitOrRollback()
                throw error
            }
        }
    }
    
    /// Starts a transaction for the lifetime of the closure
    /// and does not commit or rollback automatically. Just
    /// makes sure it reclaims the connection.
    public func beginNoCommit<Output: Sendable>(
        _ kind: Transaction.Kind,
        execute: @Sendable (consuming Transaction) async throws -> Output
    ) async throws -> Output {
        let tx = try await begin(kind)
        let conn = tx.connection
        
        do {
            let output = try await execute(tx)
            await reclaim(connection: conn, kind: kind)
            return output
        } catch {
            await reclaim(connection: conn, kind: kind)
            throw error
        }
    }
}
