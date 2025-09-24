//
//  Test.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/13/25.
//

import Foundation

public extension Queries {
    /// A query to use in a unit test. Will execute the provided function
    /// and record the call counts of all functions.
    ///
    /// Example:
    /// ```swift
    /// // In test
    /// class ViewModel {
    ///     let loadTodo: any LoadTodoQuery
    /// }
    ///
    /// let loadTodo = Queries.Test<Int, Todo>()
    ///
    /// let viewModel = ViewModel(loadTodo: loadTodo)
    /// try await viewModel.load()
    ///
    /// #expect(loadTodo.executeCallCount == 1)
    /// ```
    final class Test<Input, Output>: Query, @unchecked Sendable
        where Input: Sendable, Output: Sendable
    {
        private let execute: @Sendable (Input) throws -> Output
        public private(set) var executeCallCount = 0
        public private(set) var observeCallCount = 0
        public private(set) var startObservationCallCount = 0
        public private(set) var cancelObservationCallCount = 0
        private let lock = NSLock()
        
        public init(execute: @escaping @Sendable (Input) throws -> Output) {
            self.execute = execute
        }
        
        public convenience init(_ output: Output) {
            self.init(execute: { _ in output })
        }
        
        public convenience init(error: any Error) {
            self.init(execute: { _ in throw error })
        }
        
        public convenience init() where Output == () {
            self.init(execute: { _ in () })
        }
        
        public var transactionKind: Transaction.Kind { .read }
        public var watchedTables: Set<String> { [] }
        public var connection: any Connection { NoopConnection() }
        
        public func execute(_ input: Input, tx: borrowing Transaction) throws -> Output {
            lock.withLock { executeCallCount += 1 }
            return try execute(input)
        }
        
        public nonisolated func observation(_ input: Input) -> any QueryObservation<Output> {
            lock.withLock { observeCallCount += 1 }
            return Observation(input: input, query: self)
        }
        
        private func incrementStartObservationCallCount() {
            lock.withLock { startObservationCallCount += 1 }
        }
        
        private func incrementCancelObservationCallCount() {
            lock.withLock { cancelObservationCallCount += 1 }
        }
        
        struct Observation: QueryObservation {
            let input: Input
            let query: Test

            func start(
                onChange: @escaping (Output) -> Void,
                onComplete: @escaping (Error?) -> Void
            ) {
                query.incrementStartObservationCallCount()
                
                do {
                    try onChange(query.execute(input))
                    onComplete(nil)
                } catch {
                    onComplete(error)
                }
            }
            
            func cancel() {
                query.incrementCancelObservationCallCount()
            }
        }
    }
}
