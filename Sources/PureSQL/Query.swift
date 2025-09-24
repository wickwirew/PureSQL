//
//  Query.swift
//  PureSQL
//
//  Created by Wes Wickwire on 3/29/25.
//

/// Declares a type that queries for data of type `Output`
/// with the input of type `Input`.
///
/// This does not care about where the data comes from
/// and is not aware of any database or transaction. If a
/// a `any Query` is injected into a model in a unit test
/// we can pass in a different `Query` with the same input
/// and output as a mock.
public protocol Query<Input, Output>: Sendable {
    /// The type the query takes as an input
    associatedtype Input: Sendable
    /// The type the query returns as an output
    associatedtype Output: Sendable
    
    /// Whether the query requires a read or write transaction.
    var transactionKind: Transaction.Kind { get }
    /// The current connection to the database
    var connection: any Connection { get }
    /// Any table this query depends on. When tables change
    /// if this query is observed then we will only requery
    /// if those tables changed.
    var watchedTables: Set<String> { get }
    
    /// Executes the query once within the given transaction.
    ///
    /// Example:
    /// ```swift
    /// try await queries.begin(.read) { tx in
    ///     let user = try userQuery.execute(with: 42, tx: tx)
    ///     print("Fetched user:", user)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: The query input or parameters to use for execution.
    ///   - tx: The active transaction in which the query will be executed.
    /// - Returns: The decoded `Output` of the query.
    /// - Throws: An error if the query fails to execute or if the results
    ///   cannot be decoded into the expected type.
    func execute(_ input: Input, tx: borrowing Transaction) throws -> Output
    
    /// Initializes a QueryObservation that watches the database for
    /// changes on anything that affects the query and emits changes
    /// overtime.
    ///
    /// This likely will not be used directly yet using `observe` instead.
    func observation(_ input: Input) -> any QueryObservation<Output>
}

public extension Query {
    /// Executes the query once and returns the result.
    ///
    /// Example:
    /// ```swift
    /// let user = try await userQuery.execute(with: 42, tx: tx)
    /// ```
    ///
    /// - Parameters:
    ///   - input: The query input or parameters to use for execution.
    ///   - tx: The active transaction in which the query will be executed.
    /// - Returns: The decoded `Output` of the query.
    /// - Throws: An error if the query fails to execute or if the results
    ///   cannot be decoded into the expected type.
    func execute(_ input: Input) async throws -> Output {
        try await connection.begin(transactionKind) { tx in
            try execute(input, tx: tx)
        }
    }

    func observation(_ input: Input) -> any QueryObservation<Output> {
        // By default just return a DatabaseQueryObservation
        DatabaseQueryObservation(
            query: self,
            input: input,
            watchedTables: watchedTables,
            connection: connection
        )
    }
    
    /// Observes the results of a database query and streams updates as the
    /// underlying data changes.
    ///
    /// This method returns an `AsyncSequence` that first yields the current
    /// results of the query, then continues to emit new values whenever the
    /// relevant database tables are modified. Use this when you need to react
    /// to live changes in the database.
    ///
    /// Example:
    /// ```swift
    /// for await row in query.observe(with: input) {
    ///     print("Row updated:", row)
    /// }
    /// ```
    ///
    /// - Parameter input: The query or input definition used to fetch results.
    /// - Returns: A `QueryStream` sequence of `Output` values that reflect
    ///   both the initial results and subsequent changes.
    func observe(_ input: Input) -> QueryStream<Output> {
        QueryStream(observation(input))
    }
}

public extension Query where Input == () {
    /// Executes the query once within the given transaction.
    ///
    /// Example:
    /// ```swift
    /// try await queries.begin(.read) { tx in
    ///     let user = try userQuery.execute(tx: tx)
    ///     print("Fetched user:", user)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - tx: The active transaction in which the query will be executed.
    /// - Returns: The decoded `Output` of the query.
    /// - Throws: An error if the query fails to execute or if the results
    ///   cannot be decoded into the expected type.
    func execute(tx: borrowing Transaction) throws -> Output {
        return try execute((), tx: tx)
    }
    
    /// Executes the query once and returns the result.
    ///
    /// Example:
    /// ```swift
    /// let user = try await userQuery.execute()
    /// ```
    ///
    /// - Returns: The decoded `Output` of the query.
    /// - Throws: An error if the query fails to execute or if the results
    ///   cannot be decoded into the expected type.
    func execute() async throws -> Output {
        return try await execute(())
    }
    
    /// Observes the results of a database query and streams updates as the
    /// underlying data changes.
    ///
    /// This method returns an `AsyncSequence` that first yields the current
    /// results of the query, then continues to emit new values whenever the
    /// relevant database tables are modified. Use this when you need to react
    /// to live changes in the database.
    ///
    /// Example:
    /// ```swift
    /// for await row in query.observe() {
    ///     print("Row updated:", row)
    /// }
    /// ```
    ///
    /// - Returns: A `QueryStream` sequence of `Output` values that reflect
    ///   both the initial results and subsequent changes.
    func observe() -> QueryStream<Output> {
        return observe(())
    }
}
