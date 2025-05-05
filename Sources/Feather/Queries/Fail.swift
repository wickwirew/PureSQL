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
                onError: @escaping (any Error) -> Void
            ) {
                onError(error)
            }
            
            func cancel() {}
        }
    }
}
