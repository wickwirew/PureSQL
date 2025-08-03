//
//  Connection.swift
//  Otter
//
//  Created by Wes Wickwire on 3/13/25.
//

/// A connection is an interface into the database. This is not
/// directly mapped to a default SQLite connection like `SQLiteConnection`
/// but is a much more high level of abstraction that allows for safe
/// communication to a database.
public protocol Connection: Sendable {
    /// Starts observation for the given subscriber
    func observe(subscriber: DatabaseSubscriber)

    /// Cancels the observation for the given subscriber
    func cancel(subscriber: DatabaseSubscriber)

    func begin<Output>(
        _ kind: Transaction.Kind,
        execute: @Sendable (borrowing Transaction) throws -> Output
    ) async throws -> Output
}

/// A no operation database connection that does nothing.
public struct NoopConnection: Connection {
    public init() {}
    
    public func observe(subscriber: any DatabaseSubscriber) {}
    
    public func cancel(subscriber: any DatabaseSubscriber) {}
    
    public func begin<Output>(
        _ kind: Transaction.Kind,
        execute: @Sendable (borrowing Transaction) throws -> Output
    ) async throws -> Output {
        try execute(Transaction(connection: NoopRawConnection(), kind: kind))
    }
}

/// A type that has a database connection.
/// Useful for the queries structures.
///
/// Note: This should not be explicitly used and is
/// intended only for the codegen.
public protocol ConnectionWrapper: Connection {
    var connection: any Connection { get }
}

public extension ConnectionWrapper {
    func observe(subscriber: DatabaseSubscriber) {
        connection.observe(subscriber: subscriber)
    }

    func cancel(subscriber: DatabaseSubscriber) {
        connection.cancel(subscriber: subscriber)
    }

    func begin<Output>(
        _ kind: Transaction.Kind,
        execute: @Sendable (borrowing Transaction) throws -> Output
    ) async throws -> Output {
        try await connection.begin(kind, execute: execute)
    }
}
