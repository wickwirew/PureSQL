//
//  DatabaseQuery.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/5/25.
//

/// A default implementation of a `Query`. Expects to be executed
/// against a real database and not a Noop.
///
/// This is the structure that the codegen of the compiler expects to use.
public struct DatabaseQuery<Input, Output>: Query
    where Input: Sendable, Output: Sendable
{
    public let connection: any Connection
    public let transactionKind: Transaction.Kind
    public let watchedTables: Set<String>
    public let execute: @Sendable (Input, borrowing Transaction) throws -> Output
    
    /// Initializes a `DatabaseQuery`. This a query that will be handed
    /// the input and transaction when execute is called.
    ///
    /// ```swift
    /// DatabaseQuery<In, Out>(.read, in: connection) { input, tx in
    ///     ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - transactionKind: Whether its a read or write
    ///   - connection: The connection to execute the query with
    ///   - execute: A closure to run on `execute`.
    public init(
        _ transactionKind: Transaction.Kind,
        in connection: any Connection,
        watchingTables watchedTables: Set<String> = [],
        execute: @escaping @Sendable (Input, borrowing Transaction) throws -> Output
    ) {
        self.connection = connection
        self.transactionKind = transactionKind
        self.execute = execute
        self.watchedTables = watchedTables
    }
    
    public func execute(
        _ input: Input,
        tx: borrowing Transaction
    ) throws -> Output {
        guard tx.kind >= transactionKind else {
            throw PureSQLError.cannotWriteInAReadTransaction
        }
        
        return try execute(input, tx)
    }
}
