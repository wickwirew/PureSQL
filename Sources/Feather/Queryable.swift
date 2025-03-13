//
//  Queryable.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

/// An injectable query that has the database erased.
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

extension Queryable where Input == () {
    func execute(in database: DB) async throws -> Output {
        return try await execute(with: (), in: database)
    }
    
    func execute(tx: borrowing Transaction) throws -> Output {
        return try execute(with: (), tx: tx)
    }
    
    func observe(
        in database: DB,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Self> {
        return observe(with: (), in: database, handle: handle, cancelled: cancelled)
    }
    
    func stream(in database: DB) -> AsyncThrowingStream<Output, Error> {
        return stream(with: (), in: database)
    }
}

extension Queryable where Input == (), DB == ErasedDatabase {
    func execute() async throws -> Output {
        return try await execute(with: (), in: .shared)
    }
    
    func observe(
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Self> {
        return observe(with: (), in: .shared, handle: handle, cancelled: cancelled)
    }
    
    func stream() -> AsyncThrowingStream<Output, Error> {
        return stream(with: (), in: .shared)
    }
}

extension Queryable where DB == ErasedDatabase {
    func execute(with input: Input) async throws -> Output {
        return try await execute(with: input, in: .shared)
    }
    
    func observe(
        with input: Input,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Self> {
        return observe(with: input, in: .shared, handle: handle, cancelled: cancelled)
    }
    
    func stream(with input: Input) -> AsyncThrowingStream<Output, Error> {
        return stream(with: input, in: .shared)
    }
}
