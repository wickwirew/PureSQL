//
//  Queryable.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol Queryable<Input, Output>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    /// Whether the query requires a read or write transaction.
    var transactionKind: TransactionKind { get }
    
    func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output
}

extension Queryable {
    public func execute(
        with input: Input,
        in database: any Database
    ) async throws -> Output {
        let tx = try await database.begin(transactionKind)
        return try execute(with: input, tx: tx)
    }
}

extension Queryable where Input == () {
    func execute(in database: any Database) async throws -> Output {
        return try await execute(with: (), in: database)
    }
    
    func execute(tx: borrowing Transaction) throws -> Output {
        return try execute(with: (), tx: tx)
    }
    
    func observe(
        in database: any Database,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Input, Output> {
        return observe(with: (), in: database, handle: handle, cancelled: cancelled)
    }
    
    func stream(in database: any Database) -> AsyncThrowingStream<Output, Error> {
        return stream(with: (), in: database)
    }
}

/// An injectable query that can be executed without explicitly
/// sending in the database.
public protocol Query<Input, Output>: Queryable {
    func execute(
        with input: Input
    ) async throws -> Output
    
    func observe(
        with input: Input,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Input, Output>
}

public extension Query {
    func stream(
        with input: Input
    ) -> AsyncThrowingStream<Output, Error> {
        return AsyncThrowingStream<Output, Error> { continuation in
            let observation = self.observe(with: input) { output in
                continuation.yield(output)
            } cancelled: {
                // Nothing to do
            }
            
            continuation.onTermination = { _ in
                observation.cancel()
            }
        }
    }
}

public extension Query where Input == () {
    func execute() async throws -> Output {
        return try await execute(with: ())
    }
    
    func observe(
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Input, Output> {
        return observe(with: (), handle: handle, cancelled: cancelled)
    }
    
    func stream() -> AsyncThrowingStream<Output, Error> {
        return stream(with: ())
    }
}


func meow<Q: Queryable>(query: Q, database: any Database) async throws
    where Q.Input == Int, Q.Output == Int
{
    for try await result in query.stream(with: 1, in: database) {
        
    }
    
    try await meow2(query: query.with(database: database))
}

func meow2(query: any Query<Int, Int>) async throws {
    for try await result in query.map({ $0 }).stream(with: 1) {

    }
}
