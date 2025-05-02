//
//  Query.swift
//  Feather
//
//  Created by Wes Wickwire on 3/29/25.
//

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
