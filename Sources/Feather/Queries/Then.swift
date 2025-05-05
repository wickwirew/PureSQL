//
//  Then.swift
//  Feather
//
//  Created by Wes Wickwire on 5/4/25.
//

extension Queries {
    public struct Then<First, Second>: DatabaseQuery
        where First: DatabaseQuery, Second: DatabaseQuery
    {
        public typealias Input = First.Input
        public typealias Output = (First.Output, Second.Output)
        
        let first: First
        let second: Second
        let secondInput: @Sendable (First.Input, First.Output) -> Second.Input
        
        public var database: any Database {
            return first.database
        }
        
        public var transactionKind: TransactionKind {
            return max(first.transactionKind, second.transactionKind)
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

public extension DatabaseQuery {
    func then<Next>(_ next: Next) -> Queries.Then<Self, Next>
        where Next: DatabaseQuery, Self.Input == Next.Input
    {
        return Queries.Then(first: self, second: next) { input, _ in input }
    }
    
    func then<Next>(_ next: Next) -> Queries.Then<Self, Next>
        where Next: DatabaseQuery, Next.Input == ()
    {
        return Queries.Then(first: self, second: next) { _, _ in () }
    }
    
    func then<Next>(
        _ next: Next,
        nextInput: @Sendable @escaping (Input, Output) -> Next.Input
    ) -> Queries.Then<Self, Next>
        where Next: DatabaseQuery
    {
        return Queries.Then(first: self, second: next) { input, output in nextInput(input, output) }
    }
}
