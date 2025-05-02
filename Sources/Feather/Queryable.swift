//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol DatabaseQuery<Input, Output>: Query {
    /// Whether the query requires a read or write transaction.
    var transactionKind: TransactionKind { get }
    
    var database: any Database { get }
    
    func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output
}

public extension DatabaseQuery {
    func execute(with input: Input) async throws -> Output {
        let tx = try await database.begin(transactionKind)
        let output = try execute(with: input, tx: tx)
        try tx.commit()
        return output
    }
    
    func observe(with input: Input) -> any QueryObservation<Output> {
        return DatabaseQueryObservation(query: self, input: input)
    }
}

public extension DatabaseQuery where Input == () {
    func observe() -> any QueryObservation<Output> {
        return observe(with: ())
    }
}

public struct DatabaseQueryImpl<Input, Output>: DatabaseQuery
    where Input: Sendable, Output: Sendable
{
    public let database: any Database
    public let transactionKind: TransactionKind
    public let execute: @Sendable (Input, borrowing Transaction) throws -> Output
    
    public init(
        database: any Database,
        tx: TransactionKind,
        execute: @escaping @Sendable (Input, borrowing Transaction) throws -> Output
    ) {
        self.database = database
        self.transactionKind = tx
        self.execute = execute
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output {
        try execute(input, tx)
    }
}
