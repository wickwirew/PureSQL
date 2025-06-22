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
    let query: any Query<Input, Output>

    public init(_ query: any Query<Input, Output>) {
        self.query = query
    }

    public func execute(with input: Input) async throws -> Output {
        try await query.execute(with: input)
    }

    public func observe(with input: Input) -> any QueryObservation<Output> {
        query.observe(with: input)
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
