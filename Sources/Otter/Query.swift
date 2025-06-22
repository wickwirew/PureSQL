//
//  Query.swift
//  Otter
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
    
    /// Executes the query
    ///
    /// - Parameter input: The query's input
    /// - Returns: The query's output
    func execute(with input: Input) async throws -> Output
    
    /// Observes the query's value over time. When the database
    /// changes new values will automatically be refreshed.
    ///
    /// The `QueryObservation` is an `AsyncSequence` and can
    /// be observed with a for loop.
    ///
    /// ```swift
    /// for try await value in query.observe() {
    ///     print(value)
    /// }
    /// ```
    ///
    /// - Parameter input: The query's input
    /// - Returns: The observation.
    func observe(with input: Input) -> any QueryObservation<Output>
}

public extension Query where Input == () {
    /// Executes the query
    func execute() async throws -> Output {
        return try await execute(with: ())
    }
    
    /// Observes the query's value over time. When the database
    /// changes new values will automatically be refreshed.
    ///
    /// The `QueryObservation` is an `AsyncSequence` and can
    /// be observed with a for loop.
    ///
    /// ```swift
    /// for try await value in query.observe() {
    ///     print(value)
    /// }
    /// ```
    ///
    /// - Returns: The observation.
    func observe() -> any QueryObservation<Output> {
        return observe(with: ())
    }
}
