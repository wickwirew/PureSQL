//
//  DatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol DatabaseQuery<Input, Output>: Query {
    /// Whether the query requires a read or write transaction.
    var transactionKind: TransactionKind { get }
    
    var connection: any Connection { get }
    
    func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output
}

public extension DatabaseQuery {
    func execute(with input: Input) async throws -> Output {
        let tx = try await connection.begin(transactionKind)
        let output = try execute(with: input, tx: tx)
        try await tx.commit()
        return output
    }
    
    func observe(with input: Input) -> any QueryObservation<Output> {
        return DatabaseQueryObservation(query: self, input: input)
    }
}

public extension DatabaseQuery where Input == () {
    func execute(tx: borrowing Transaction) throws -> Output {
        return try execute(with: (), tx: tx)
    }
    
    func observe() -> any QueryObservation<Output> {
        return observe(with: ())
    }
}
