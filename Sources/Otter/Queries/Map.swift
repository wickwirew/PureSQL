//
//  Map.swift
//  Otter
//
//  Created by Wes Wickwire on 5/4/25.
//

public extension Queries {
    /// Applies a transform to the queries result
    struct Map<Base: Query, Output: Sendable>: Query {
        public typealias Input = Base.Input
        public typealias Output = Output
        /// The upstream query to transform
        let base: Base
        /// The transform to apply to the output
        let transform: @Sendable (Base.Input, Base.Output) throws -> Output

        public func execute(with input: Base.Input) async throws -> Output {
            try await transform(input, base.execute(with: input))
        }
        
        public func observe(with input: Base.Input) -> any QueryObservation<Output> {
            return Observation(base: base.observe(with: input), input: input, transform: transform)
        }
        
        struct Observation: QueryObservation {
            let base: any QueryObservation<Base.Output>
            let input: Base.Input
            /// The transform to apply to the output
            let transform: @Sendable (Base.Input, Base.Output) throws -> Output
            
            func start(
                onChange: @escaping @Sendable (Output) -> Void,
                onComplete: @escaping @Sendable (Error?) -> Void
            ) {
                base.start { upstream in
                    do {
                        try onChange(transform(input, upstream))
                    } catch {
                        onComplete(error)
                    }
                } onComplete: { error in
                    onComplete(error)
                }
            }
            
            func cancel() {
                base.cancel()
            }
        }
    }
}

extension Queries.Map: DatabaseQuery where Base: DatabaseQuery {
    public var connection: any Connection {
        return base.connection
    }
    
    public var transactionKind: Transaction.Kind {
        return base.transactionKind
    }
    
    public var watchedTables: Set<String> {
        return base.watchedTables
    }
    
    public func execute(
        with input: Base.Input,
        tx: borrowing Transaction
    ) throws -> Output {
        return try transform(input, base.execute(with: input, tx: tx))
    }
}

public extension Query {
    /// Transforms the output of the query.
    ///
    /// - Parameter transform: Closure to transform the output
    /// - Returns: A query with the output type of the closure result.
    func map<NewOutput>(
        _ transform: @Sendable @escaping (Output) throws -> NewOutput
    ) -> Queries.Map<Self, NewOutput> {
        return Queries.Map(base: self) { _, entity in try transform(entity) }
    }
    
    /// If a `nil` value is returned from the query, then an will throw an error.
    ///
    /// The input closure for the error takes the `input` as a parameter.
    /// This allows for less ambiguous erros to be thrown by passing an id
    /// or any other identifying information.
    ///
    /// ```swift
    /// query.throwIfNotFound { id in NotFound(id: id) }
    /// ```
    ///
    /// If the `error` is `nil` then it will default to a `entityNotFound` erro
    /// to be thrown.
    ///
    /// - Parameter error: A closure to construct the error to be thrown.
    /// - Returns: A query with a non optional result type, that will throw in case of an error.
    func throwIfNotFound<Wrapped>(
        _ error: (@Sendable (Input) -> Error)? = nil
    ) -> Queries.Map<Self, Wrapped> where Output == Wrapped? {
        return Queries.Map(base: self) { input, entity in
            guard let entity else { throw error?(input) ?? OtterError.entityWasNotFound }
            return entity
        }
    }
    
    /// If a `nil` value is returned from the query, then an will throw an error.
    ///
    /// - Parameter error: The error to throw if `nil`
    /// - Returns: A query with a non optional result type, that will throw in case of an error.
    func throwIfNotFound<Wrapped>(
        _ error: @Sendable @autoclosure @escaping () -> Error
    ) -> Queries.Map<Self, Wrapped> where Output == Wrapped? {
        return Queries.Map(base: self) { input, entity in
            guard let entity else { throw error() }
            return entity
        }
    }
    
    /// Will replace any `nil` value with the given input value.
    /// The `value` closure will be called for each `nil` value
    /// received from the upstream query.
    ///
    /// - Parameter value: The value to return instead of `nil`
    /// - Returns: A query with a non optional result type, that default the value if `nil`
    func replaceNil<Wrapped>(
        with value: @Sendable @autoclosure @escaping () -> Wrapped
    ) -> Queries.Map<Self, Wrapped> where Output == Wrapped? {
        return Queries.Map(base: self) { _, entity in
            return entity ?? value()
        }
    }
}
