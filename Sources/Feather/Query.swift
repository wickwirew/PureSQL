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
