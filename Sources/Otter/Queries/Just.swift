//
//  Just.swift
//  Otter
//
//  Created by Wes Wickwire on 5/4/25.
//

public extension Queries {
    /// A query that returns just one result that does not fail.
    /// This can be really useful for dependency injection. So if
    /// a model takes a query, if it is abstracted to an `any Query`
    /// or one of the generated `typealias`'s this can be sent in
    /// its place during a test or preview.
    ///
    /// ```swift
    /// class ListModel {
    ///     let fetchAllItems: any FetchAllItemsQuery
    /// }
    ///
    /// let model = ListModel(
    ///     fetchAllItems: Queries.Just([.mock(), .mock()])
    /// )
    /// ```
    struct Just<Input, Output>: Query
        where Input: Sendable, Output: Sendable
    {
        /// The output to return each time.
        let output: Output
        
        public init(_ output: Output) {
            self.output = output
        }
        
        public init() where Output == () {
            self = Just(())
        }
        
        public init() where Output: ExpressibleByStringLiteral {
            self = Just("")
        }
        
        public init() where Output: ExpressibleByIntegerLiteral {
            self = Just(0)
        }
        
        public init() where Output: ExpressibleByBooleanLiteral {
            self = Just(false)
        }
        
        public init() where Output: ExpressibleByArrayLiteral {
            self = Just([])
        }
        
        public init<T>() where Output == T? {
            self = Just(nil)
        }
        
        public var transactionKind: Transaction.Kind { .read }
        
        public var watchedTables: Set<String> { [] }
        
        public var connection: any Connection { NoopConnection() }
        
        public func execute(with input: Input) async throws -> Output {
            return output
        }
        
        public func execute(
            _ input: Input,
            tx: borrowing Transaction
        ) throws -> Output {
            return output
        }
        
        public func observation(_ input: Input) -> any QueryObservation<Output> {
            return Observation(output: output)
        }
        
        struct Observation: QueryObservation {
            let output: Output
            
            func start(
                onChange: @escaping (Output) -> Void,
                onComplete: @escaping (Error?) -> Void
            ) {
                onChange(output)
                // Complete instantly
                onComplete(nil)
            }
            
            func cancel() {}
        }
    }
}
