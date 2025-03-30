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
    public struct WithDatabase<Base: DatabaseQuery>: DatabaseQuery, Query {
        /// The original query that requires a database
        let base: Base
        /// The database to execute the query in
        let database: any Database
        
        public var transactionKind: TransactionKind {
            return base.transactionKind
        }
        
        public func execute(
            with input: Base.Input,
            in _: ErasedDatabase
        ) async throws -> Base.Output {
            return try await base.execute(with: input, in: database)
        }
        
        public func execute(
            with input: Base.Input,
            tx: borrowing Transaction
        ) throws -> Base.Output {
            return try base.execute(with: input, tx: tx)
        }
        
        public func observe(
            with input: Input,
            in _: ErasedDatabase,
            handle: @Sendable @escaping (Output) -> Void,
            cancelled: @Sendable @escaping () -> Void
        ) -> QueryObservation<Input, Output> {
            return base.observe(with: input, in: database, handle: handle, cancelled: cancelled)
        }
        
        public func execute(
            with input: Base.Input
        ) async throws -> Base.Output {
            return try await base.execute(with: input, in: database)
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
    public struct Just<Input, Output>: DatabaseQuery
        where Input: Sendable, Output: Sendable
    {
        let output: Output
        
        public init(_ output: Output) {
            self.output = output
        }
        
        public var transactionKind: TransactionKind {
            return .read
        }
        
        public func execute(
            with input: Input,
            in _: ()
        ) async throws -> Output {
            return output
        }
        
        public func execute(
            with input: Input,
            tx: borrowing Transaction
        ) throws -> Output {
            return output
        }
    }
    
    public struct Then<First, Second>: DatabaseQuery
        where First: DatabaseQuery, Second: DatabaseQuery,
              First.Output == Second.Input
    {
        let first: First
        let second: Second
        
        public typealias DB = any Database
        
        public var transactionKind: TransactionKind {
            return max(first.transactionKind, second.transactionKind)
        }
        
        public func execute(
            with input: First.Input,
            tx: borrowing Transaction
        ) throws -> (First.Output, Second.Output) {
            let firstOutput = try first.execute(with: input, tx: tx)
            let secondOutput = try second.execute(with: firstOutput, tx: tx)
            return (firstOutput, secondOutput)
        }
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
}
