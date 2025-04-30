//
//  Queries.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public enum Queries {
    /// Replaces the `Database` associated type with the input
    /// resulting in a query with a `Void` database.
    /// Allows for the erasing of the database so a query can be
    /// passed around and be able to be executed without
    /// having the caller worry about by what.
    public struct WithDatabase<Base: DatabaseQuery>: Query {
        /// The original query that requires a database
        let base: Base
        /// The database to execute the query in
        let database: any Database
        
        public func execute(
            with input: Base.Input
        ) async throws -> Base.Output {
            return try await base.execute(with: input, in: database)
        }
        
        public func observe(with input: Input) -> any QueryObservation<Output> {
            return base.observe(with: input, in: database)
        }
    }
    
    /// Applies a transform to the queries result
    public struct Map<Base: DatabaseQuery, Output: Sendable>: DatabaseQuery {
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: @Sendable (Base.Output) throws -> Output
        
        public var transactionKind: TransactionKind {
            return base.transactionKind
        }
        
        public func execute(
            with input: Base.Input,
            in database: any Database
        ) async throws -> Output {
            return try await transform(base.execute(with: input, in: database))
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
        
        let first: First
        let second: Second
        let secondInput: @Sendable (First.Input, First.Output) -> Second.Input
        
        public typealias DB = any Database
        
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
    
    public struct None<Input: Sendable>: DatabaseQuery {
        public init() {}
        
        public var transactionKind: TransactionKind {
            return .read
        }
        
        public func execute(
            with input: Input,
            tx: borrowing Transaction
        ) throws {}
    }
}

public extension DatabaseQuery {
    func with(database: any Database) -> Queries.WithDatabase<Self> {
        return Queries.WithDatabase(base: self, database: database)
    }
    
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
