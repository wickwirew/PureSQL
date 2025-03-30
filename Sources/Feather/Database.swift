//
//  Database.swift
//  Feather
//
//  Created by Wes Wickwire on 3/13/25.
//

public protocol Database: Actor {
    nonisolated func observe(subscriber: DatabaseSubscriber)
    
    nonisolated func cancel(subscriber: DatabaseSubscriber)
    
    func begin(
        _ transaction: TransactionKind
    ) async throws(FeatherError) -> sending Transaction
    
    nonisolated func didCommit(transaction: borrowing Transaction)
}
