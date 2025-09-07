//
//  AnyQuery.swift
//  Otter
//
//  Created by Wes Wickwire on 5/4/25.
//

/// Simply a wrapper for an `any Query`. Due to limitations operators
/// like `map` cannot be used on an `any Query` due to the reliance
/// on the original base query type. Erasing to this can allow for
/// use of the operators.
public struct AnyQuery<Input: Sendable, Output: Sendable>: Query {
    public let transactionKind: Transaction.Kind
    public let connection: any Connection
    public let watchedTables: Set<String>
    private let _execute: @Sendable (Input, borrowing Transaction) throws -> Output
    private let _observe: @Sendable (Input) -> any QueryObservation<Output>
    
    public init(
        transactionKind: Transaction.Kind,
        connection: any Connection,
        watchedTables: Set<String>,
        execute: @Sendable @escaping (Input, borrowing Transaction) throws -> Output,
        observe: @Sendable @escaping (Input) -> any QueryObservation<Output>
    ) {
        self.transactionKind = transactionKind
        self.connection = connection
        self.watchedTables = watchedTables
        self._execute = execute
        self._observe = observe
    }
    
    public init(_ query: any Query<Input, Output>) {
        self = AnyQuery(
            transactionKind: query.transactionKind,
            connection: query.connection,
            watchedTables: query.watchedTables,
            execute: { try query.execute($0, tx: $1) },
            observe: { query.observation($0) }
        )
    }
    
    public func execute(_ input: Input, tx: borrowing Transaction) throws -> Output {
        try _execute(input, tx)
    }

    public func observation(_ input: Input) -> any QueryObservation<Output> {
        _observe(input)
    }
}

public extension Query {
    /// Earases a query to an `AnyQuery`. With Swifts `any` keyword
    /// this should not really be needed most of the time. However some
    /// of the operators like `Map` take `Self` as a generic disallowing
    /// any query typed as `any Query` to be used. Erasing to a concrete
    /// `AnyQuery` can get around this however.
    ///
    /// ```swift
    /// func example(query: any Query<(), Int>) {
    ///     // Not allowed because `any`
    ///     query.map { $0 + 1 }
    ///
    ///     // Since type is now `AnyQuery` `map` can be used.
    ///     query.eraseToAnyQuery()
    ///         .map { $0 + 1 }
    /// }
    /// ```
    ///
    /// - Returns: An erased query.
    func eraseToAnyQuery() -> AnyQuery<Input, Output> {
        return AnyQuery(self)
    }
}
