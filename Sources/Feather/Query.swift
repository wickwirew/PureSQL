//
//  Query.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

public protocol QueryContext {
    associatedtype Error: Swift.Error
}

public protocol Query<Input, Output, Context> {
    associatedtype Input
    associatedtype Output
    associatedtype Context
    
    func execute(with input: Input, in context: Context) async throws -> Output
}

public extension Query where Input == () {
    func execute(in context: Context) async throws -> Output {
        try await self.execute(with: (), in: context)
    }
}

public extension Query {
    func with(input: Input) -> Queries.WithInput<Self> {
        return Queries.WithInput(base: self, input: input)
    }
}

public enum Queries {
    public struct Just<Input, Output, Context>: Query {
        public let output: Output
        
        public init(_ output: Output) {
            self.output = output
        }
        
        public func execute(with input: Input, in context: Context) async throws -> Output {
            output
        }
    }
        
    public struct WithInput<Base: Query>: Query {
        public let base: Base
        public let input: Base.Input
        
        public init(base: Base, input: Base.Input) {
            self.input = input
            self.base = base
        }
        
        public func execute(with _: (), in context: Base.Context) async throws -> Base.Output {
            try await base.execute(with: input, in: context)
        }
    }
}

public protocol DatabaseQuery<Input, Output>: Query {
    func statement(in connection: borrowing Connection, with input: Input) throws(FeatherError) -> Statement
}

public extension DatabaseQuery where Output: RangeReplaceableCollection, Output.Element: RowDecodable {
    func execute(
        with input: Input,
        in context: borrowing Connection
    ) async throws -> Output {
        let statement = try statement(in: context, with: input)
        var cursor = Cursor(of: statement)
        var result = Output()
        
        while try cursor.step() {
            try result.append(Output.Element(cursor: cursor))
        }
        
        return result
    }
}

public extension DatabaseQuery where Output: RowDecodable {
    func execute(
        with input: Input,
        in context: borrowing Connection
    ) async throws -> Output {
        let statement = try statement(in: context, with: input)
        var cursor = Cursor(of: statement)
        
        guard try cursor.step() else {
            throw FeatherError.queryReturnedNoValue
        }
        
        return try Output(cursor: cursor)
    }
}
