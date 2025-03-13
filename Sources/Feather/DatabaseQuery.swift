//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

extension Queryable where DB == ConnectionPool {
//    public func values(
//        with input: Input,
//        in database: Database
//    ) -> QueryObservation<Input, Output> {
//        return QueryObservation(
//            query: self,
//            input: input,
//            pool: database
//        )
//    }
    
    public func execute(
        with input: Input,
        in database: ConnectionPool
    ) async throws -> Output {
        let transaction = try await database.begin(transactionKind)
        let result = try execute(with: input, tx: transaction)
        try transaction.commit()
        return result
    }
}

/// A database query that fetches any array of rows.
public struct FetchManyQuery<Input, Output>: Queryable
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
public struct FetchSingleQuery<Input, Output>: Queryable
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
        tx: borrowing Transaction
    ) throws -> Output? {
        let statement = try statement(input: input, transaction: tx)
        var cursor = Cursor<Output>(of: statement)
        return try cursor.next()
    }
}

/// A query that has no return value.
public struct VoidQuery<Input>: Queryable where Input: Sendable {
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
        tx: borrowing Transaction
    ) throws {
        let statement = try statement(input: input, transaction: tx)
        _ = try statement.step()
    }
}
