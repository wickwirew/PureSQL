//
//  Queryable.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public typealias Query<Input, Output> = Queryable<Input, Output, ()>

public protocol Queryable<Input, Output, DB>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    associatedtype DB: Sendable
    
    /// Whether the query requires a read or write transaction.
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

extension Queryable where DB == any Database {
    public func execute(
        with input: Input,
        in database: DB
    ) async throws -> Output {
        let tx = try await database.begin(transactionKind)
        return try execute(with: input, tx: tx)
    }
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
    ) -> QueryObservation<Input, Output, DB> {
        return observe(with: (), in: database, handle: handle, cancelled: cancelled)
    }
    
    func stream(in database: DB) -> AsyncThrowingStream<Output, Error> {
        return stream(with: (), in: database)
    }
}

public extension Queryable where Input == (), DB == () {
    func execute() async throws -> Output {
        return try await execute(with: (), in: ())
    }
}


/// An injectable query that can be executed without explicitly
/// sending in the database.
//    func execute(
//        with input: Input
//    ) async throws -> Output
//    
//    func observe(
//        with input: Input,
//        handle: @Sendable @escaping (Output) -> Void,
//        cancelled: @Sendable @escaping () -> Void
//    ) -> QueryObservation<Input, Output>

//
//public extension Query {
//    func stream(
//        with input: Input
//    ) -> AsyncThrowingStream<Output, Error> {
//        return AsyncThrowingStream<Output, Error> { continuation in
//            let observation = self.observe(with: input) { output in
//                continuation.yield(output)
//            } cancelled: {
//                // Nothing to do
//            }
//            
//            continuation.onTermination = { _ in
//                observation.cancel()
//            }
//        }
//    }
//}

