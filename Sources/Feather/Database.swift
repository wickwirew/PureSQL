//
//  Database.swift
//  Feather
//
//  Created by Wes Wickwire on 3/13/25.
//

public protocol Database: Actor {
    func observe(subscriber: DatabaseSubscriber) throws(FeatherError)
    nonisolated func cancel(subscriber: DatabaseSubscriber)
    func begin(
        _ transaction: TransactionKind
    ) async throws(FeatherError) -> sending Transaction
}

/// Only used when the database has been erased using the `with(database:)` operator.
/// No methods in this are actually called. The `WithDatabase` query holds the database
/// that will actually be used.
public actor ErasedDatabase: Database {
    static let shared = ErasedDatabase()
    
    private init() {}
    
    public func observe(subscriber: DatabaseSubscriber) throws(FeatherError) {}
    
    public nonisolated func cancel(subscriber: DatabaseSubscriber) {}
    
    public func begin(
        _ transaction: TransactionKind
    ) async throws(FeatherError) -> sending Transaction {
        fatalError("Cannot be used directly")
    }
}
