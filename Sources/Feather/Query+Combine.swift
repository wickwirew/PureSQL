//
//  Query+Combine.swift
//  Feather
//
//  Created by Wes Wickwire on 6/17/25.
//

#if canImport(Combine)
import Combine
import Foundation

/// A Combine publisher for query observation.
public struct QueryPublisher<Output>: Publisher {
    public typealias Failure = Error
    
    /// The query being observed
    let query: any Query<(), Output>
    
    public func receive<S>(subscriber: S)
        where S: Subscriber, Failure == S.Failure, Output == S.Input
    {
        let subscription = Subscription(subscriber: subscriber, query: query)
        subscriber.receive(subscription: subscription)
    }
    
    public final class Subscription<S: Subscriber>: Combine.Subscription, @unchecked Sendable
        where S.Input == Output, S.Failure == Failure
    {
        private var subscriber: S
        private let query: any Query<(), Output>
        private var state: State = .pending
        private let lock = NSRecursiveLock()
        
        enum State {
            case subscribed(Subscribers.Demand, any QueryObservation<Output>)
            case pending
        }
        
        init(subscriber: S, query: any Query<(), Output>) {
            self.subscriber = subscriber
            self.query = query
        }
        
        public func request(_ demand: Subscribers.Demand) {
            lock.withLock {
                switch state {
                case .pending:
                    // Received first demand, start observation
                    let observation = query.observe()
                    
                    observation.start { [weak self] output in
                        self?.receive(output: output)
                    } onComplete: { [weak self] error in
                        if let error {
                            self?.receive(completion: .failure(error))
                        } else {
                            self?.receive(completion: .finished)
                        }
                    }
                    
                    state = .subscribed(demand, observation)
                case let .subscribed(currentDemand, observation):
                    // Increase demand
                    state = .subscribed(currentDemand + demand, observation)
                }
            }
        }
        
        public func cancel() {
            var observation: (any QueryObservation<Output>)?
            lock.withLock {
                guard case let .subscribed(_, o) = state else { return }
                state = .pending
                observation = o
            }
            observation?.cancel()
        }
        
        private func receive(output: Output) {
            lock.withLock {
                guard case let .subscribed(demand, observation) = state,
                      demand > .none else { return }
                let newDemand = subscriber.receive(output)
                state = .subscribed(demand + newDemand - 1, observation)
            }
        }
        
        private func receive(completion: Subscribers.Completion<Failure>) {
            lock.withLock {
                guard case let .subscribed(_, observation) = state else { return }
                observation.cancel()
                self.state = .pending
            }
            
            subscriber.receive(completion: completion)
        }
    }
}

public extension Query {
    /// Returns a Combine publisher that will fire once
    /// and then observe changes as the database changes.
    ///
    /// - Parameter input: The input for the query
    /// - Returns: A combine publisher
    func publisher(with input: Input) -> QueryPublisher<Output> {
        QueryPublisher(query: self.with(input: input))
    }
}

public extension Query where Input == () {
    /// Returns a Combine publisher that will fire once
    /// and then observe changes as the database changes.
    ///
    /// - Returns: A combine publisher
    func publisher() -> QueryPublisher<Output> {
        QueryPublisher(query: self)
    }
}

#endif
