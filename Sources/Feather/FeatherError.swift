//
//  FeatherError.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public enum FeatherError: Error {
    case failedToOpenConnection(path: String)
    case failedToInitializeStatement
    case columnIsNil(Int32)
    case noMoreColumns
    case queryReturnedNoValue
    case sqlite(SQLiteCode, String?)
    case txNoLongerValid
    case failedToGetConnection
    case poolCannotHaveZeroConnections
    case alreadyCommited
    case entityWasNotFound
    /// A query observation was attempted
    /// to be started twice.
    case subscriptionAlreadyStarted
    case invalidUuidString
}
