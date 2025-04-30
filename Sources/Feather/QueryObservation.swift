//
//  QueryObservation.swift
//  Feather
//
//  Created by Wes Wickwire on 3/10/25.
//

import Foundation

public final class DatabaseQueryObservation<Input, Output>: DatabaseSubscriber, QueryObservation, @unchecked Sendable
    where Input: Sendable, Output: Sendable
{
    private let query: (Input, Database) async throws -> Output
    private let input: Input
    private let database: any Database
    private let lock = NSLock()
    private let queue = Queue()
    
    private var onChange: (@Sendable (Output) -> Void)?
    private var onError: (@Sendable (Error) -> Void)?
    
    init<Query: DatabaseQuery>(
        query: Query,
        input: Input,
        database: any Database
    ) where Input == Query.Input, Output == Query.Output {
        self.query = { try await query.execute(with: $0, in: $1) }
        self.input = input
        self.database = database
    }
    
    public func receive(event: DatabaseEvent) {
        enqueueNext()
    }
    
    public func cancel() {
        lock.withLock {
            onChange = nil
            onError = nil
        }
        
        database.cancel(subscriber: self)
        queue.cancel()
    }
    
    public func start(
        onChange: @escaping @Sendable (Output) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        lock.withLock {
            self.onChange = onChange
            self.onError = onError
        }
        
        database.observe(subscriber: self)
        enqueueNext()
    }
    
    private func emitNext() async {
        guard let onChange else {
            return assertionFailure("Started without handle set")
        }
        
        do {
            let output = try await query(input, database)
            onChange(output)
        } catch {
            onError?(error)
            cancel()
        }
    }
    
    private func enqueueNext() {
        queue.enqueue { [weak self] in
            await self?.emitNext()
        }
    }
}

public protocol QueryObservation<Output>: Sendable, AsyncSequence {
    associatedtype Output: Sendable
    
    func start(
        onChange: @escaping @Sendable (Output) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    )
    
    func cancel()
}

extension QueryObservation {
    public func makeAsyncIterator() -> AsyncThrowingStream<Output, Error>.AsyncIterator {
        return asStream().makeAsyncIterator()
    }
    
    func asStream() -> AsyncThrowingStream<Output, Error> {
        AsyncThrowingStream<Output, Error> { continuation in
            start { output in
                continuation.yield(output)
            } onError: { error in
                continuation.finish(throwing: error)
            }
            
            continuation.onTermination = { _ in
                cancel()
            }
        }
    }
}
