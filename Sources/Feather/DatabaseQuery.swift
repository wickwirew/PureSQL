//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct QueryObservation<Input, Output>: AsyncSequence, Sendable
    where Input: Sendable
{
    private let query: any Query<Input, Output, ConnectionPool>
    private let input: Input
    private let pool: ConnectionPool
    private let stream: AsyncStream<()>
    private let continuation: AsyncStream<()>.Continuation

    init(
        query: any Query<Input, Output, ConnectionPool>,
        input: Input,
        pool: ConnectionPool
    ) {
        self.query = query
        self.input = input
        self.pool = pool
        (stream, continuation) = AsyncStream.makeStream()
    }
    
    public func makeAsyncIterator() -> Iterator {
        Iterator(queryObservation: self)
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        let queryObservation: QueryObservation
        var dbObservation: Observation?
        
        public mutating func next() async throws -> Output? {
            if dbObservation == nil {
                dbObservation = await queryObservation.pool.observe()
                
                return try await queryObservation.query.execute(
                    with: queryObservation.input,
                    in: queryObservation.pool
                )
            }
            
            guard let dbObservation else {
                fatalError()
            }
            
            for await _ in dbObservation {
                guard !Task.isCancelled else {
                    await queryObservation.pool.cancel(observation: dbObservation)
                    return nil
                }
                
                return try await queryObservation.query.execute(
                    with: queryObservation.input,
                    in: queryObservation.pool
                )
            }
            
            await queryObservation.pool.cancel(observation: dbObservation)
            return nil
        }
    }
}

extension Query where Database == ConnectionPool {
    public func values(
        with input: Input,
        in database: Database
    ) -> QueryObservation<Input, Output> {
        return QueryObservation(
            query: self,
            input: input,
            pool: database
        )
    }
}

/// A database query that fetches any array of rows.
public struct FetchManyQuery<Input, Output>: Query
    where Input: Sendable,
        Output: RangeReplaceableCollection & ExpressibleByArrayLiteral,
        Output.Element: RowDecodable
{
    public let transactionKind: TransactionKind
    private let _statement: @Sendable (Input, borrowing Transaction) throws -> Statement
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @Sendable @escaping (Input, borrowing Transaction) throws -> Statement
    ){
        self.transactionKind = transactionKind
        self._statement = statement
    }

    public func statement(
        input: Input,
        transaction: borrowing Transaction
    ) throws -> Statement {
        return try _statement(input, transaction)
    }
    
    public func execute(
        with input: Input,
        in database: ConnectionPool
    ) async throws -> Output {
        let transaction = try await database.begin(transactionKind)
        let result = try execute(with: input, tx: transaction)
        try transaction.commit()
        return result
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output {
        let statement = try statement(input: input, transaction: tx)
        var cursor = Cursor<Output.Element>(of: statement)
        var result: Output = []
        
        while let element = try cursor.next() {
            result.append(element)
        }
        
        return result
    }
}

/// A database that fetches a single element. Can return `nil`
public struct FetchSingleQuery<Input, Output>: Query
    where Input: Sendable, Output: RowDecodable
{
    public let transactionKind: TransactionKind
    private let _statement: @Sendable (Input, borrowing Transaction) throws -> Statement
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @Sendable @escaping (Input, borrowing Transaction) throws -> Statement
    ) {
        self.transactionKind = transactionKind
        self._statement = statement
    }

    public func statement(
        input: Input,
        transaction: borrowing Transaction
    ) throws -> Statement {
        return try _statement(input, transaction)
    }
    
    public func execute(
        with input: Input,
        in database: ConnectionPool
    ) async throws -> Output? {
        let transaction = try await database.begin(transactionKind)
        let result = try execute(with: input, tx: transaction)
        try transaction.commit()
        return result
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output? {
        let statement = try statement(input: input, transaction: tx)
        var cursor = Cursor<Output>(of: statement)
        return try cursor.next()
    }
}

/// A query that has no return value.
public struct VoidQuery<Input>: Query where Input: Sendable {
    public typealias Output = ()
    
    public let transactionKind: TransactionKind
    private let _statement: @Sendable (Input, borrowing Transaction) throws -> Statement
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @Sendable @escaping (Input, borrowing Transaction) throws -> Statement
    ) {
        self.transactionKind = transactionKind
        self._statement = statement
    }

    public func statement(
        input: Input,
        transaction: borrowing Transaction
    ) throws -> Statement {
        return try _statement(input, transaction)
    }
    
    public func execute(
        with input: Input,
        in database: ConnectionPool
    ) async throws {
        let transaction = try await database.begin(transactionKind)
        try execute(with: input, tx: transaction)
        try transaction.commit()
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws {
        let statement = try statement(input: input, transaction: tx)
        _ = try statement.step()
    }
}
