//
//  Just.swift
//  Feather
//
//  Created by Wes Wickwire on 5/4/25.
//

extension Queries {
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
    public struct Just<Input, Output>: Query
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
        
        public init() where Output: ExpressibleByArrayLiteral {
            self = Just([])
        }
        
        public init<T>() where Output == T? {
            self = Just(nil)
        }
        
        public func execute(with input: Input) async throws -> Output {
            return output
        }
        
        public func observe(with input: Input) -> any QueryObservation<Output> {
            return Observation(output: output)
        }
        
        struct Observation: QueryObservation {
            let output: Output
            
            func start(
                onChange: @escaping (Output) -> Void,
                onError: @escaping (any Error) -> Void
            ) {
                onChange(output)
            }
            
            func cancel() {}
        }
    }
}
