//
//  Queries.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public enum Queries {
    /// Applies a transform to the queries result
    public struct Map<Base: DatabaseQuery, Output: Sendable>: DatabaseQuery {
        public typealias Input = Base.Input
        public typealias Output = Output
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: @Sendable (Base.Output) throws -> Output
        /// The database to execute the query on
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
    
    public struct Then<First, Second>: DatabaseQuery
        where First: DatabaseQuery, Second: DatabaseQuery
    {
        public typealias Input = First.Input
        public typealias Output = (First.Output, Second.Output)
        
        let first: First
        let second: Second
        let secondInput: @Sendable (First.Input, First.Output) -> Second.Input
        
        public var database: any Database {
            return first.database
        }
        
        public var transactionKind: TransactionKind {
            return max(first.transactionKind, second.transactionKind)
        }
        
        public func execute(
            with input: First.Input,
            tx: borrowing Transaction
        ) throws -> (First.Output, Second.Output) {
            let firstOutput = try first.execute(with: input, tx: tx)
            let secondInput = secondInput(input, firstOutput)
            let secondOutput = try second.execute(with: secondInput, tx: tx)
            return (firstOutput, secondOutput)
        }
    }
}

public extension DatabaseQuery {
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
    
    func then<Next>(_ next: Next) -> Queries.Then<Self, Next>
        where Next: DatabaseQuery, Self.Input == Next.Input
    {
        return Queries.Then(first: self, second: next) { input, _ in input }
    }
    
    func then<Next>(_ next: Next) -> Queries.Then<Self, Next>
        where Next: DatabaseQuery, Next.Input == ()
    {
        return Queries.Then(first: self, second: next) { _, _ in () }
    }
    
    func then<Next>(
        _ next: Next,
        nextInput: @Sendable @escaping (Input, Output) -> Next.Input
    ) -> Queries.Then<Self, Next>
        where Next: DatabaseQuery
    {
        return Queries.Then(first: self, second: next) { input, output in nextInput(input, output) }
    }
}
