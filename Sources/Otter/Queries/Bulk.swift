//
//  Bulk.swift
//  Otter
//
//  Created by Wes Wickwire on 7/4/25.
//

extension Queries {
    public struct Bulk<Base: Query>: Query {
        public typealias Input = [Base.Input]
        public typealias Output = [Base.Output]
        
        let base: Base
        
        public var transactionKind: Transaction.Kind {
            base.transactionKind
        }
        
        public var connection: any Connection {
            base.connection
        }
        
        public var watchedTables: Set<String> {
            base.watchedTables
        }
        
        public func execute(
            with input: [Base.Input],
            tx: borrowing Transaction
        ) throws -> [Base.Output] {
            var results: [Base.Output] = []
            
            for input in input {
                try results.append(base.execute(with: input, tx: tx))
            }
            
            return results
        }
    }
}

extension Query {
    /// Returns a query that executes the same query in bulk
    /// for each input.
    ///
    /// Note: The individual statements are still executed one
    /// at a time but is done in a single transaction so the
    /// write to disk only happens once.
    public func bulk() -> Queries.Bulk<Self> {
        Queries.Bulk(base: self)
    }
}
