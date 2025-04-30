//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol DatabaseQuery: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    /// Whether the query requires a read or write transaction.
    var transactionKind: TransactionKind { get }
    
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
        let output = try execute(with: input, tx: tx)
        try tx.commit()
        return output
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

public extension DatabaseQuery where Input == () {
    func execute(in database: any Database) async throws -> Output {
        return try await execute(with: (), in: database)
    }
    
    func execute(tx: borrowing Transaction) throws -> Output {
        return try execute(with: (), tx: tx)
    }
    
    func observe(in database: any Database) -> any QueryObservation<Output> {
        return observe(with: (), in: database)
    }
}
