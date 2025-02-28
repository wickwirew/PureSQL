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
    public struct WithDatabase<Base: Query>: Query {
        /// The original query that requires a database
        let base: Base
        /// The database to execute the query in
        let database: Base.Database
        
        public var transactionKind: TransactionKind {
            return base.transactionKind
        }
        
        public func statement(
            input: Input,
            transaction: borrowing Transaction
        ) throws -> Statement {
            return try base.statement(
                input: input,
                transaction: transaction
            )
        }
        
        public func execute(
            with input: Base.Input,
            in _: ()
        ) async throws -> Base.Output {
            return try await base.execute(with: input, in: database)
        }
        
        public func execute(
            with input: Input,
            tx: borrowing Transaction
        ) throws -> Output {
            return try base.execute(with: input, tx: tx)
        }
    }
    
    /// Applies a transform to the queries result
    public struct Map<Base: Query, Output>: Query {
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: (Base.Output) throws -> Output
        
        public var transactionKind: TransactionKind {
            return base.transactionKind
        }
        
        public func statement(
            input: Input,
            transaction: borrowing Transaction
        ) throws -> Statement {
            return try base.statement(
                input: input,
                transaction: transaction
            )
        }
        
        public func execute(
            with input: Base.Input,
            in database: Base.Database
        ) async throws -> Output {
            return try await transform(base.execute(with: input, in: database))
        }
        
        public func execute(
            with input: Input,
            tx: borrowing Transaction
        ) throws -> Output {
            return try transform(base.execute(with: input, tx: tx))
        }
    }
}

public extension Query {
    func with(database: Database) -> Queries.WithDatabase<Self> {
        return Queries.WithDatabase(base: self, database: database)
    }
    
    func map<NewOutput>(
        _ transform: @escaping (Output) throws -> NewOutput
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
        with value: @autoclosure @escaping () -> Wrapped
    ) -> Queries.Map<Self, Wrapped> where Output == Wrapped? {
        return Queries.Map(base: self) { entity in
            return entity ?? value()
        }
    }
}

struct MyDB {
    var migrations: [String] {
        return [
            ""
        ]
    }
    
    var queries: [String] {
        return [
            """
            DEFINE QUERY fetchUsers AS
            SELECT * FROM user;
            """,
        ]
    }
}
