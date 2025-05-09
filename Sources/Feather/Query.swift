//
//  Query.swift
//  Feather
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
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func execute(with input: Input) async throws -> Output
    
    func observe(with input: Input) -> any QueryObservation<Output>
}

public extension Query where Input == () {
    func execute() async throws -> Output {
        return try await execute(with: ())
    }
    
    func observe() -> any QueryObservation<Output> {
        return observe(with: ())
    }
}
