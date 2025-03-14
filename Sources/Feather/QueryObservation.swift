//
//  QueryObservation.swift
//  Feather
//
//  Created by Wes Wickwire on 3/10/25.
//

public final class QueryObservation<Input, Output>: DatabaseSubscriber, Sendable
    where Input: Sendable, Output: Sendable
{
    private let query: any Queryable<Input, Output>
    private let input: Input
    private let database: any Database
    private let handle: @Sendable (Output) -> Void
    private let cancelled: @Sendable () -> Void
    
    init(
        query: any Queryable<Input, Output>,
        input: Input,
        database: any Database,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) {
        self.query = query
        self.input = input
        self.database = database
        self.handle = handle
        self.cancelled = cancelled
    }
    
    public func receive(event: DatabaseEvent) {
        Task {
            try await handle(query.execute(with: input, in: database))
        }
    }
    
    public func onCancel() {
        cancelled()
    }
    
    public func cancel() {
        database.cancel(subscriber: self)
    }
    
    public func start() async throws {
        try await database.observe(subscriber: self)
        try await emitNext()
    }
    
    private func emitNext() async throws {
        let output = try await query.execute(with: input, in: database)
        handle(output)
    }
    
}

extension Queryable {
    func observe(
        with input: Input,
        in database: any Database,
        handle: @Sendable @escaping (Output) -> Void,
        cancelled: @Sendable @escaping () -> Void
    ) -> QueryObservation<Input, Output> {
        QueryObservation<Input, Output>(
            query: self,
            input: input,
            database: database,
            handle: handle,
            cancelled: cancelled
        )
    }
    
    func stream(
        with input: Input,
        in database: any Database
    ) -> AsyncThrowingStream<Output, Error> {
        return AsyncThrowingStream<Output, Error> { continuation in
            let observation = self.observe(
                with: input,
                in: database
            ) { output in
                continuation.yield(output)
            } cancelled: {
                // Nothing to do
            }
            
            continuation.onTermination = { _ in
                observation.cancel()
            }
        }
    }
}
