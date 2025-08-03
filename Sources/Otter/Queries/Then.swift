//
//  Then.swift
//  Otter
//
//  Created by Wes Wickwire on 5/4/25.
//

public extension Queries {
    struct Then<First, Second>: Query
        where First: Query, Second: Query
    {
        public typealias Input = First.Input
        public typealias Output = (First.Output, Second.Output)
        
        let first: First
        let second: Second
        let secondInput: @Sendable (First.Input, First.Output) -> Second.Input
        
        public var connection: any Connection {
            return first.connection
        }
        
        public var transactionKind: Transaction.Kind {
            return max(first.transactionKind, second.transactionKind)
        }
        
        public var watchedTables: Set<String> {
            return first.watchedTables.union(second.watchedTables)
        }
        
        public func execute(
            with input: First.Input,
            tx: borrowing Transaction
        ) throws -> (First.Output, Second.Output) {
            let firstOutput = try first.execute(with: input, tx: tx)
            let secondInput = secondInput(input, firstOutput)
            let secondOutput = try second.execute(with: secondInput, tx: tx)
            return (firstOutput, secondOutput)
        }
    }
}

public extension Query {
    /// After the this query, the `next` query will be executed with the
    /// same input as the first. Each query is executed within the same
    /// transaction.
    ///
    /// - Parameter next: The query to execute next
    /// - Returns: A query that execute `self` then the `next` query
    func then<Next>(_ next: Next) -> Queries.Then<Self, Next>
        where Next: Query, Self.Input == Next.Input
    {
        return Queries.Then(first: self, second: next) { input, _ in input }
    }
    
    /// After the this query, the `next` query will be executed.
    /// Each query is executed within the same transaction.
    ///
    /// - Parameter next: The query to execute next
    /// - Returns: A query that execute `self` then the `next` query
    func then<Next>(_ next: Next) -> Queries.Then<Self, Next>
        where Next: Query, Next.Input == ()
    {
        return Queries.Then(first: self, second: next) { _, _ in () }
    }
    
    /// After the this query, the `next` query will be executed.
    /// Each query is executed within the same transaction.
    ///
    /// - Parameter next: The query to execute next
    /// - Parameter nextInput: A closure to map the input and output
    /// of the first query to the input of the `next`.
    /// - Returns: A query that execute `self` then the `next` query
    func then<Next>(
        _ next: Next,
        nextInput: @Sendable @escaping (Input, Output) -> Next.Input
    ) -> Queries.Then<Self, Next>
        where Next: Query
    {
        return Queries.Then(first: self, second: next) { input, output
            in nextInput(input, output)
        }
    }
}
