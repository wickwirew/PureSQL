//
//  AnyDatabaseQuery.swift
//  Feather
//
//  Created by Wes Wickwire on 5/5/25.
//

/// A query that is executed against a database.
public struct AnyDatabaseQuery<Input, Output>: DatabaseQuery
    where Input: Sendable, Output: Sendable
{
    public let connection: any Connection
    public let transactionKind: TransactionKind
    public let execute: @Sendable (Input, borrowing Transaction) throws -> Output
    
    
    /// Initializes a `AnyDatabaseQuery`. This a query that will be handed
    /// the input and transaction when execute is called.
    ///
    /// ```swift
    /// AnyDatabaseQuery<In, Out>(.read, in: connection) { input, tx in
    ///     ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - transactionKind: Whether its a read or write
    ///   - connection: The connection to execute the query with
    ///   - execute: A closure to run on `execute`.
    public init(
        _ transactionKind: TransactionKind,
        in connection: any Connection,
        execute: @escaping @Sendable (Input, borrowing Transaction) throws -> Output
    ) {
        self.connection = connection
        self.transactionKind = transactionKind
        self.execute = execute
    }
    
    public func execute(
        with input: Input,
        tx: borrowing Transaction
    ) throws -> Output {
        try execute(input, tx)
    }
}

public extension DatabaseQuery {
    /// Erases the current query to a `AnyDatabaseQuery`. Useful if you are using
    /// operators like `map` or `mapInput` which can have quite the long signature
    /// for combined queries.
    ///
    /// - Returns: `self` erased to a `AnyDatabaseQuery`
    func eraseToAnyDatabaseQuery() -> AnyDatabaseQuery<Input, Output> {
        AnyDatabaseQuery(transactionKind, in: connection) { input, tx in
            try self.execute(with: input, tx: tx)
        }
    }
}
