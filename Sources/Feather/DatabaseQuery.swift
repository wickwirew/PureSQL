//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

/// A database query that fetches any array of rows.
public struct FetchManyQuery<Input, Output>: DatabaseQuery
    where Input: Sendable,
        Output: RangeReplaceableCollection & ExpressibleByArrayLiteral & Sendable,
        Output.Element: RowDecodable & Sendable
{
    public let transactionKind: TransactionKind
    private let statement: @Sendable (Input, borrowing Transaction) throws -> Statement
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @Sendable @escaping (Input, borrowing Transaction) throws -> Statement
    ){
        self.transactionKind = transactionKind
        self.statement = statement
    }
   
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output {
        let statement = try statement(input, tx)
        var cursor = Cursor<Output.Element>(of: statement)
        var result: Output = []
        
        while let element = try cursor.next() {
            result.append(element)
        }
        
        return result
    }
}

/// A database that fetches a single element. Can return `nil`
public struct FetchSingleQuery<Input, Output>: DatabaseQuery
    where Input: Sendable, Output: RowDecodable & Sendable
{
    public let transactionKind: TransactionKind
    private let statement: @Sendable (Input, borrowing Transaction) throws -> Statement

    public init(
        _ transactionKind: TransactionKind,
        statement: @Sendable @escaping (Input, borrowing Transaction) throws -> Statement
    ) {
        self.transactionKind = transactionKind
        self.statement = statement
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output? {
        let statement = try statement(input, tx)
        var cursor = Cursor<Output>(of: statement)
        return try cursor.next()
    }
}

/// A query that has no return value.
public struct VoidQuery<Input>: DatabaseQuery where Input: Sendable {
    public typealias Output = ()
    
    public let transactionKind: TransactionKind
    private let statement: @Sendable (Input, borrowing Transaction) throws -> Statement
    
    public typealias DB = any Database
    
    public init(
        _ transactionKind: TransactionKind,
        statement: @Sendable @escaping (Input, borrowing Transaction) throws -> Statement
    ) {
        self.transactionKind = transactionKind
        self.statement = statement
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws {
        let statement = try statement(input, tx)
        _ = try statement.step()
    }
}
