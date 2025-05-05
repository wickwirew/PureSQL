//
//  MapInput.swift
//  Feather
//
//  Created by Wes Wickwire on 5/4/25.
//

extension Queries {
    /// Applies a transform to the queries input
    public struct MapInput<Base: Query, Input: Sendable>: Query {
        public typealias Output = Base.Output
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: @Sendable (Input) -> Base.Input

        public func execute(with input: Input) async throws -> Output {
            try await base.execute(with: transform(input))
        }
        
        public func observe(with input: Input) -> any QueryObservation<Output> {
            return base.observe(with: transform(input))
        }
    }
}

extension Queries.MapInput: DatabaseQuery where Base: DatabaseQuery {
    public var connection: any Connection {
        return base.connection
    }
    
    public var transactionKind: TransactionKind {
        return base.transactionKind
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output {
        return try base.execute(with: transform(input), tx: tx)
    }
}

public extension Query {
    /// Transforms the input value before passing it to the query.
    ///
    /// - Parameter transform: The closure to transform the input
    /// - Returns: A query with a input type of the resulting closure.
    func mapInput<NewInput>(
        to _: NewInput.Type = NewInput.self,
        _ transform: @Sendable @escaping (NewInput) -> Input
    ) -> Queries.MapInput<Self, NewInput> {
        return Queries.MapInput(base: self, transform: transform)
    }
}
