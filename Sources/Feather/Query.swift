//
//  Query.swift
//  Feather
//
//  Created by Wes Wickwire on 3/29/25.
//

public protocol Query<Input, Output> {
    associatedtype Input
    associatedtype Output
    
    func execute(with input: Input) async throws -> Output
    
    func observe(
        with input: Input,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Input, Output>
}

public extension Query where Input == () {
    func execute() async throws -> Output {
        return try await execute(with: ())
    }
    
    func observe(
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Input, Output> {
        return observe(with: (), handle: handle, cancelled: cancelled)
    }
}
