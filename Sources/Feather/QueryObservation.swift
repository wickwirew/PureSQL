//
//  QueryObservation.swift
//  Feather
//
//  Created by Wes Wickwire on 3/10/25.
//

import Foundation

public final class DatabaseQueryObservation<Query>: DatabaseSubscriber, QueryObservation, @unchecked Sendable
    where Query: DatabaseQuery
{
    private let query: Query
    private let input: Query.Input
    private let lock = NSLock()
    private let queue = Queue()
    
    private var onChange: (@Sendable (Query.Output) -> Void)?
    private var onComplete: (@Sendable (Error?) -> Void)?
    
    init(
        query: Query,
        input: Query.Input
    ) {
        self.query = query
        self.input = input
    }
    
    public func receive(change: DatabaseChange) {
        // If any table that we are watching changed
        // reexecute the query.
        guard !change.affectedTables
            .intersection(query.watchedTables)
            .isEmpty else { return }
        enqueueNext()
    }
    
    public func cancel() {
        lock.withLock {
            onChange = nil
            onComplete = nil
        }
        
        query.connection.cancel(subscriber: self)
        queue.cancel()
    }
    
    public func start(
        onChange: @escaping @Sendable (Query.Output) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        lock.withLock {
            self.onChange = onChange
            self.onComplete = onComplete
        }
        
        query.connection.observe(subscriber: self)
        enqueueNext()
    }
    
    private func emitNext() async {
        guard let onChange else {
            return assertionFailure("Started without handle set")
        }
        
        do {
            guard query.transactionKind != .write else {
                throw FeatherError.cannotObserveWriteQuery
            }
            
            let output = try await query.execute(with: input)
            onChange(output)
        } catch {
            onComplete?(error)
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
        onComplete: @escaping @Sendable (Error?) -> Void
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
            } onComplete: { error in
                continuation.finish(throwing: error)
            }
            
            continuation.onTermination = { _ in
                cancel()
            }
        }
    }
}


public final class QueryObservation2 {
    
}
