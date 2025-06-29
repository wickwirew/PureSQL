//
//  OtterError.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

public enum OtterError: Error, Equatable {
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
    case cannotDecode(String, from: String, reason: String?)
    case cannotEncode(String, to: String, reason: String?)
    case decodingError(String)
    case encodingError(String)
    case requiredAssociationFailed(parent: String, childKey: String)
    case cannotObserveWriteQuery
    case cannotWriteInAReadTransaction
    case unexpectedNil

    public static func cannotDecode(
        _ type: Any.Type,
        from otherType: Any.Type,
        reason: String? = nil
    ) -> OtterError {
        return .cannotDecode("\(type)", from: "\(otherType)", reason: reason)
    }

    public static func cannotEncode(
        _ type: Any.Type,
        to otherType: Any.Type,
        reason: String? = nil
    ) -> OtterError {
        return .cannotEncode("\(type)", to: "\(otherType)", reason: reason)
    }
}
