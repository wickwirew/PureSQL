//
//  QueryObservation.swift
//  Feather
//
//  Created by Wes Wickwire on 3/10/25.
//

public final class QueryObservation<Q: Queryable>: DatabaseSubscriber, Sendable
    where Q.Input: Sendable
{
    private let query: Q
    private let input: Q.Input
    private let database: Q.DB
    private let handle: @Sendable (Q.Output) -> Void
    
//    private var currentTask: Task<Q.Output,
    
    init(
        query: Q,
        input: Q.Input,
        database: Q.DB,
        handle: @Sendable @escaping (Q.Output) -> Void
    ) {
        self.query = query
        self.input = input
        self.database = database
        self.handle = handle
    }
    
    public func receive(event: DatabaseEvent) {
        Task {
            try await handle(query.execute(with: input, in: database))
        }
    }
    
    public func onCancel() {
        
    }
    
//    private func next() async throws -> Q.Output {
//        return
//    }
//
////    public func makeAsyncIterator() -> Iterator {
////        Iterator(queryObservation: self)
////    }
//
//    public struct Iterator: AsyncIteratorProtocol {
//        let queryObservation: QueryObservation
//        
//        public mutating func next() async throws -> Q.Output? {
//            guard let dbObservation else {
//                dbObservation = await queryObservation.pool.observe()
//                return try await execute()
//            }
//            
//            for await _ in dbObservation {
//                guard !Task.isCancelled else {
//                    await queryObservation.pool.cancel(observation: dbObservation)
//                    return nil
//                }
//                
//                return try await execute()
//            }
//            
//            await queryObservation.pool.cancel(observation: dbObservation)
//            return nil
//        }
//        
//        private func execute() async throws -> Output {
//            return try await queryObservation.query.execute(
//                with: queryObservation.input,
//                in: queryObservation.pool
//            )
//        }
//    }
}
