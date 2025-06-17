//
//  Fail.swift
//  Feather
//
//  Created by Wes Wickwire on 5/5/25.
//

extension Queries {
    /// A query that always fails with the given error.
    public struct Fail<Input, Output>: Query
        where Input: Sendable, Output: Sendable
    {
        /// The error to throw on execution
        let error: any Error
        
        /// Initializes a query that always fails with an error.
        /// This is useful for unit tests and previews to test
        /// how a part of an application behaives when an error
        /// is thrown.
        ///
        /// - Parameter error: The error to throw
        public init(_ error: any Error) {
            self.error = error
        }
        
        public func execute(with input: Input) async throws -> Output {
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
