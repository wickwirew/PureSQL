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
}

extension Query where Input == () {
    func execute() async throws -> Output {
        return try await execute(with: ())
    }
}
