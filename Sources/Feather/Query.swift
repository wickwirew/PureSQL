//
//  Query.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol Query<Input, Output, Database> {
    associatedtype Input
    associatedtype Output
    associatedtype Database
    
    var transactionKind: TransactionKind { get }
    
    func statement(
        input: Input,
        transaction: Transaction
    ) throws -> Statement
    
    func execute(
        with input: Input,
        in database: Database
    ) async throws -> Output
    
    func execute(
        with input: Input,
        tx: Transaction
    ) throws -> Output
}

public enum Queries {
    public struct WithDatabase<Base: Query>: Query {
        let base: Base
        let database: Base.Database
        
        public var transactionKind: TransactionKind {
            return base.transactionKind
        }
        
        public func statement(input: Input, transaction: Transaction) throws -> Statement {
            return try base.statement(
                input: input,
                transaction: transaction
            )
        }
        
        public func execute(with input: Base.Input, in _: ()) async throws -> Base.Output {
            return try await base.execute(with: input, in: database)
        }
        
        public func execute(with input: Input, tx: Transaction) throws -> Output {
            return try base.execute(with: input, tx: tx)
        }
    }
    
    public struct Map<Base: Query, Output>: Query {
        let base: Base
        let transform: (Base.Output) throws -> Output
        
        public var transactionKind: TransactionKind {
            return base.transactionKind
        }
        
        public func statement(input: Input, transaction: Transaction) throws -> Statement {
            return try base.statement(
                input: input,
                transaction: transaction
            )
        }
        
        public func execute(with input: Base.Input, in database: Base.Database) async throws -> Output {
            return try await transform(base.execute(with: input, in: database))
        }
        
        public func execute(with input: Input, tx: Transaction) throws -> Output {
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
    
    func throwIfNotFound<Wrapped>() -> Queries.Map<Self, Output> where Output == Wrapped? {
        return Queries.Map(base: self) { entity in
            guard let entity else {
                throw FeatherError.entityWasNotFound
            }
            
            return entity
        }
    }
}

public extension Query {
    func execute(with input: Input) async throws -> Output
        where Database == ()
    {
        return try await execute(with: input, in: ())
    }
    
    func execute(in database: Database) async throws -> Output
        where Input == ()
    {
        return try await execute(with: (), in: database)
    }
    
    func execute() async throws -> Output
        where Input == (), Database == ()
    {
        return try await execute(with: (), in: ())
    }

    func execute(tx: Transaction) throws -> Output
        where Input == ()
    {
        return try execute(with: (), tx: tx)
    }
}

public struct DatabaseQuery<Input, Output>: Query {
    public let transactionKind: TransactionKind
    private let _statement: (Input, Transaction) throws -> Statement
    private let _execute: (consuming Statement, Transaction) throws -> Output
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @escaping (Input, Transaction) throws -> Statement,
        execute: @escaping (consuming Statement, Transaction) -> Output
    ) {
        self.transactionKind = transactionKind
        self._statement = statement
        self._execute = execute
    }
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @escaping (Input, Transaction) throws -> Statement
    ) where Output: RowDecodable {
        self.transactionKind = transactionKind
        self._statement = statement
        // Note: There seems to be a bug in swift that does not mark `s` as consuming
        // even though in `_execute`s declaration it is.
        self._execute = { (s: consuming Statement, t) in try t.fetchOne(of: Output.self, statement: s) }
    }
    
    public init<Element>(
        _ transactionKind: TransactionKind,
        statement: @escaping (Input, Transaction) throws -> Statement
    ) where Element: RowDecodable, Output == [Element] {
        self.transactionKind = transactionKind
        self._statement = statement
        // Note: There seems to be a bug in swift that does not mark `s` as consuming
        // even though in `_execute`s declaration it is.
        self._execute = { (s: consuming Statement, t) in try t.fetchMany(of: Element.self, statement: s) }
    }
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @escaping (Input, Transaction) throws -> Statement
    ) where Output == () {
        self.transactionKind = transactionKind
        self._statement = statement
        // Note: There seems to be a bug in swift that does not mark `s` as consuming
        // even though in `_execute`s declaration it is.
        self._execute = { (s: consuming Statement, t) in try t.execute(statement: s) }
    }
    
    public func statement(
        input: Input,
        transaction: Transaction
    ) throws -> Statement {
        return try _statement(input, transaction)
    }
    
    public func execute(
        with input: Input,
        in database: any TransactionProvider
    ) async throws -> Output {
        let transaction = try await database.begin(transactionKind)
        let result = try execute(with: input, tx: transaction)
        try transaction.commit()
        return result
    }
    
    public func execute(
        with input: Input,
        tx: Transaction
    ) throws -> Output {
        let statement = try statement(input: input, transaction: tx)
        return try _execute(statement, tx)
    }
}


func meow<Q: Query>(query: Q, db: Q.Database) async throws where Q.Input == Int {
    let result = try await query.execute(with: 1, in: db)

    let query2 = query.with(database: db)
    let result2 = try await query2.execute(with: 1)
}
