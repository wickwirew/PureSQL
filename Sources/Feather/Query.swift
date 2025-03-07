//
//  Query.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol Query<Input, Output, Database>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output
    associatedtype Database: Sendable
    
    var transactionKind: TransactionKind { get }
    
    func statement(
        input: Input,
        transaction: borrowing Transaction
    ) throws -> Statement
    
    func execute(
        with input: Input,
        in database: Database
    ) async throws -> Output
    
    func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output
    
    func values(
        with input: Input,
        in database: Database
    ) -> QueryObservation<Input, Output>
}

public extension Query {
    func execute(with input: Input) async throws -> Output
        where Database == ()
    {
        return try await execute(with: input, in: ())
    }
    
    func execute(in database: Database) async throws -> Output
        where Input == ()
    {
        return try await execute(with: (), in: database)
    }
    
    func execute() async throws -> Output
        where Input == (), Database == ()
    {
        return try await execute(with: (), in: ())
    }

    func execute(tx: borrowing Transaction) throws -> Output
        where Input == ()
    {
        return try execute(with: (), tx: tx)
    }
}

public extension Query {
    func values(with input: Input) -> QueryObservation<Input, Output>
        where Database == ()
    {
        return values(with: input, in: ())
    }
    
    func values(in database: Database) -> QueryObservation<Input, Output>
        where Input == ()
    {
        return values(with: (), in: database)
    }
    
    func values() -> QueryObservation<Input, Output>
        where Input == (), Database == ()
    {
        return values(with: (), in: ())
    }
}
