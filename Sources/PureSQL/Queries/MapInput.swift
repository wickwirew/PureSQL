//
//  MapInput.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/4/25.
//

public extension Queries {
    /// Applies a transform to the queries input
    struct MapInput<Base: Query, Input: Sendable>: Query {
        public typealias Output = Base.Output
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: @Sendable (Input) -> Base.Input
        
        public var transactionKind: Transaction.Kind {
            base.transactionKind
        }
        
        public var connection: any Connection {
            base.connection
        }
        
        public var watchedTables: Set<String> {
            base.watchedTables
        }

        public func execute(_ input: Input, tx: borrowing Transaction) throws -> Base.Output {
            try base.execute(transform(input), tx: tx)
        }

        public func observation(_ input: Input) -> any QueryObservation<Output> {
            return base.observation(transform(input))
        }
    }
}

public extension Query {
    /// Transforms the input value before passing it to the query.
    /// Allows you to change the input type of a query. Useful if
    /// merging multiple queries together using `then`.
    ///
    /// - Parameter transform: The closure to transform the input
    /// - Returns: A query with a input type of the resulting closure.
    func mapInput<NewInput>(
        to _: NewInput.Type = NewInput.self,
        _ transform: @Sendable @escaping (NewInput) -> Input
    ) -> Queries.MapInput<Self, NewInput> {
        return Queries.MapInput(base: self, transform: transform)
    }

    func with(_ input: Input) -> Queries.MapInput<Self, Void> {
        Queries.MapInput(base: self) { input }
    }
}
