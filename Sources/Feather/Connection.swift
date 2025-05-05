//
//  Connection.swift
//  Feather
//
//  Created by Wes Wickwire on 3/13/25.
//

/// A connection is an interface into the database. This is not
/// directly mapped to a default SQLite connection like `SQLiteConnection`
/// but is a much more high level of abstraction that allows for safe
/// communication to a database.
public protocol Connection: Actor {
    /// Starts observation for the given subscriber
    nonisolated func observe(subscriber: DatabaseSubscriber)
    
    /// Cancels the observation for the given subscriber
    nonisolated func cancel(subscriber: DatabaseSubscriber)
    
    func begin(
        _ transaction: TransactionKind
    ) async throws(FeatherError) -> sending Transaction
    
    nonisolated func didCommit(transaction: borrowing Transaction)
}
