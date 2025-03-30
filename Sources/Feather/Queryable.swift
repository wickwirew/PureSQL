//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol DatabaseQuery<Input, Output>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    /// Whether the query requires a read or write transaction.
    var transactionKind: TransactionKind { get }

    func execute(
        with input: Input,
        in database: any Database
    ) async throws -> Output
    
    func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output
}

public extension DatabaseQuery {
    func execute(
        with input: Input,
        in database: any Database
    ) async throws -> Output {
        let tx = try await database.begin(transactionKind)
        return try execute(with: input, tx: tx)
    }
    
    func observe(
        with input: Input,
        in database: any Database
    ) -> any QueryObservation<Output> {
        return DatabaseQueryObservation(
            query: self,
            input: input,
            database: database
        )
    }
}

extension DatabaseQuery where Input == () {
    func execute(in database: any Database) async throws -> Output {
        return try await execute(with: (), in: database)
    }
    
    func execute(tx: borrowing Transaction) throws -> Output {
        return try execute(with: (), tx: tx)
    }
}
