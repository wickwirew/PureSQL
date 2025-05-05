//
//  Just.swift
//  Feather
//
//  Created by Wes Wickwire on 5/4/25.
//

extension Queries {
    /// Applies a transform to the queries result
    public struct Just<Input, Output>: Query
        where Input: Sendable, Output: Sendable
    {
        let output: Output
        
        public init(_ output: Output) {
            self.output = output
        }
        
        public func execute(with input: Input) async throws -> Output {
            return output
        }
        
        public func observe(with input: Input) -> any QueryObservation<Output> {
            return Observation(output: output)
        }
        
        final class Observation: QueryObservation {
            let output: Output
            
            init(output: Output) {
                self.output = output
            }
            
            func start(
                onChange: @escaping (Output) -> Void,
                onError: @escaping (any Error) -> Void
            ) {
                onChange(output)
            }
            
            func cancel() {}
        }
    }
}
