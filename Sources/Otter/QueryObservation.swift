//
//  QueryObservation.swift
//  Otter
//
//  Created by Wes Wickwire on 3/10/25.
//

import Foundation

/// A protocol that defines the core interface for observing query results.
///
/// Conforming types provide the ability to listen for changes in query output
/// and notify subscribers when new results are available. This protocol is not
/// intended for direct use, it serves as the core type for higher
/// level abstractions such as an `AsyncSequence` or Combine publishers.
public protocol QueryObservation<Output>: Sendable {
    associatedtype Output: Sendable
    
    /// Starts the observation and delivers results to the given callbacks.
    ///
    /// - Parameters:
    ///   - onChange: Called with new results whenever they are available.
    ///   Also called once when the observation is started
    ///   - onComplete: Called when the observation ends, optionally with an error.
    func start(
        onChange: @escaping @Sendable (Output) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    )
    
    /// Cancels the observation and stops delivering updates.
    func cancel()
}

/// The default implementation of `QueryObservation` that watches a database.
///
/// `DatabaseQueryObservation` monitors a query against a database and emits new
/// results whenever the underlying data changes. It powers higher-level types
/// like `QueryStream` and Combine publishers.
///
/// Most code should not use this type directly. Instead, prefer the `observe`
/// methods which return an `AsyncSequence`
public final class DatabaseQueryObservation<Q>: @unchecked Sendable
    where Q: Query
{
    private let query: Q
    private let input: Q.Input
    private let lock = NSLock()
    private let queue = Queue()
    private let watchedTables: Set<String>
    private let connection: any Connection
    
    private var onChange: (@Sendable (Q.Output) -> Void)?
    private var onComplete: (@Sendable (Error?) -> Void)?
    
    init(
        query: Q,
        input: Q.Input,
        watchedTables: Set<String>,
        connection: any Connection
    ) {
        self.query = query
        self.input = input
        self.watchedTables = watchedTables
        self.connection = connection
    }
    
    private func emitNext() async {
        // These are scheduled asynchronously. So there is a timing
        // issue where we could `enqueueNext` then get cancelled
        // which would bring us to here with no `onChange` set.
        guard let onChange else { return }
        
        do {
            guard query.transactionKind != .write else {
                throw OtterError.cannotObserveWriteQuery
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

extension DatabaseQueryObservation: QueryObservation {
    public func start(
        onChange: @escaping @Sendable (Q.Output) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        lock.withLock {
            self.onChange = onChange
            self.onComplete = onComplete
        }
        
        connection.observe(subscriber: self)
        enqueueNext()
    }
    
    public func cancel() {
        onComplete?(nil)
        
        connection.cancel(subscriber: self)
        queue.cancel()
        
        lock.withLock {
            onChange = nil
            onComplete = nil
        }
    }
}

extension DatabaseQueryObservation: DatabaseSubscriber {
    public func receive(change: DatabaseChange) {
        // If any table that we are watching changed
        // reexecute the query.
        guard !change.affectedTables
            .intersection(watchedTables)
            .isEmpty else { return }
        enqueueNext()
    }
}

/// An `AsyncSequence` that streams query results as they change.
///
/// `QueryStream` wraps a `QueryObservation` and provides an async sequence that
/// first yields the initial results of the query, then continues to yield new
/// values whenever the underlying data changes. The sequence ends when the
/// observation is cancelled or fails with an error.
///
/// There is no need to call the initializer directly but should instead by
/// accessed through the `observe` methods on a `Query`
public struct QueryStream<Output: Sendable>: AsyncSequence, Sendable {
    private let observation: any QueryObservation<Output>
    
    public init(_ observation: any QueryObservation<Output>) {
        self.observation = observation
    }
    
    public func makeAsyncIterator() -> AsyncThrowingStream<Output, Error>.AsyncIterator {
        return asStream().makeAsyncIterator()
    }
    
    func asStream() -> AsyncThrowingStream<Output, Error> {
        AsyncThrowingStream<Output, Error> { continuation in
            observation.start { output in
                continuation.yield(output)
            } onComplete: { error in
                continuation.finish(throwing: error)
            }
            
            continuation.onTermination = { _ in
                observation.cancel()
            }
        }
    }
}
