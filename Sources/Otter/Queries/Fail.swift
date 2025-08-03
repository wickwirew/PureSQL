//
//  Fail.swift
//  Otter
//
//  Created by Wes Wickwire on 5/5/25.
//

public extension Queries {
    /// A query that always fails with the given error.
    struct Fail<Input, Output>: Query
        where Input: Sendable, Output: Sendable
    {
        /// The error to throw on execution
        let error: any Error
        
        /// The default error to throw if none is provided
        struct FailError: Error {}
        
        /// Initializes a query that always fails with an error.
        /// This is useful for unit tests and previews to test
        /// how a part of an application behaives when an error
        /// is thrown.
        ///
        /// - Parameter error: The error to throw
        public init(_ error: any Error) {
            self.error = error
        }
        
        /// Initializes a query that always fails with an error.
        /// This is useful for unit tests and previews to test
        /// how a part of an application behaives when an error
        /// is thrown.
        public init() {
            self.error = FailError()
        }
        
        public var transactionKind: Transaction.Kind { .read }
        public var watchedTables: Set<String> { [] }
        public var connection: any Connection { NoopConnection() }
        
        public func execute(with input: Input) async throws -> Output {
            throw error
        }
        
        public func execute(
            with input: Input,
            tx: borrowing Transaction
        ) throws -> Output {
            throw error
        }
        
        public func observe(with input: Input) -> any QueryObservation<Output> {
            return Observation(error: error)
        }
        
        final class Observation: QueryObservation {
            let error: any Error
            
            init(error: any Error) {
                self.error = error
            }
            
            func start(
                onChange: @escaping (Output) -> Void,
                onComplete: @escaping (Error?) -> Void
            ) {
                onComplete(error)
            }
            
            func cancel() {}
        }
    }
}
