//
//  Map.swift
//  Feather
//
//  Created by Wes Wickwire on 5/4/25.
//

extension Queries {
    /// Applies a transform to the queries result
    public struct Map<Base: Query, Output: Sendable>: Query {
        public typealias Input = Base.Input
        public typealias Output = Output
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: @Sendable (Base.Output) throws -> Output

        public func execute(with input: Base.Input) async throws -> Output {
            try await transform(base.execute(with: input))
        }
        
        public func observe(with input: Base.Input) -> any QueryObservation<Output> {
            return Observation(base: base.observe(with: input), transform: transform)
        }
        
        struct Observation: QueryObservation {
            let base: any QueryObservation<Base.Output>
            /// The transform to apply to the output
            let transform: @Sendable (Base.Output) throws -> Output
            
            func start(
                onChange: @escaping @Sendable (Output) -> Void,
                onError: @escaping @Sendable (any Error) -> Void
            ) {
                base.start { upstream in
                    do {
                        try onChange(transform(upstream))
                    } catch {
                        onError(error)
                    }
                } onError: { error in
                    onError(error)
                }
            }
            
            func cancel() {
                base.cancel()
            }
        }
    }
}

extension Queries.Map: DatabaseQuery where Base: DatabaseQuery {
    public var database: any Database {
        return base.database
    }
    
    public var transactionKind: TransactionKind {
        return base.transactionKind
    }
    
    public func execute(
        with input: Base.Input,
        tx: borrowing Transaction
    ) throws -> Output {
        return try transform(base.execute(with: input, tx: tx))
    }
}

public extension Query {
    func map<NewOutput>(
        _ transform: @Sendable @escaping (Output) throws -> NewOutput
    ) -> Queries.Map<Self, NewOutput> {
        return Queries.Map(base: self, transform: transform)
    }
    
    func throwIfNotFound<Wrapped>() -> Queries.Map<Self, Wrapped> where Output == Wrapped? {
        return Queries.Map(base: self) { entity in
            guard let entity else {
                throw FeatherError.entityWasNotFound
            }
            
            return entity
        }
    }
    
    func replaceNil<Wrapped>(
        with value: @Sendable @autoclosure @escaping () -> Wrapped
    ) -> Queries.Map<Self, Wrapped> where Output == Wrapped? {
        return Queries.Map(base: self) { entity in
            return entity ?? value()
        }
    }
}
