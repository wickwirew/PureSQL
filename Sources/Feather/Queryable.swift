//
//  Queryable.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public typealias Query<Input, Output> = Queryable<Input, Output, ErasedDatabase>

public protocol Queryable<Input, Output, DB>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    associatedtype DB: Database
    
    var transactionKind: TransactionKind { get }
    
    func execute(
        with input: Input,
        in database: DB
    ) async throws -> Output
    
    func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output
}

public extension Queryable {
    func execute(with input: Input) async throws -> Output
        where DB == ErasedDatabase
    {
        return try await execute(with: input, in: .shared)
    }
    
    func execute(in database: DB) async throws -> Output
        where Input == ()
    {
        return try await execute(with: (), in: database)
    }
    
    func execute() async throws -> Output
        where Input == (), DB == ErasedDatabase
    {
        return try await execute(with: (), in: .shared)
    }

    func execute(tx: borrowing Transaction) throws -> Output
        where Input == ()
    {
        return try execute(with: (), tx: tx)
    }
}

//public extension Queryable {
//    func observe(with input: Input) -> QueryObservation {
//        
//    }
//}


public protocol Database: Actor {
    func observe(subscriber: DatabaseSubscriber) throws(FeatherError)
    func cancel(subscriber: DatabaseSubscriber)
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
    
    public func observe(subscriber: DatabaseSubscriber) throws(FeatherError) {
        fatalError("Cannot be used directly")
    }
    
    public func cancel(subscriber: DatabaseSubscriber) {
        fatalError("Cannot be used directly")
    }
    
    public func begin(
        _ transaction: TransactionKind
    ) async throws(FeatherError) -> sending Transaction {
        fatalError("Cannot be used directly")
    }
}
