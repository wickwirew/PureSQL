//
//  FeatherError.swift
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
    case cannotDecode(String, from: String)
    case cannotEncode(String, to: String)
    case decodingError(String)
    case encodingError(String)
    case requiredAssociationFailed(parent: String, childKey: String)
    case cannotObserveWriteQuery
    case cannotWriteInAReadTransaction

    public static func cannotDecode(_ type: Any.Type, from otherType: Any.Type) -> OtterError {
        return .cannotDecode("\(type)", from: "\(otherType)")
    }

    public static func cannotEncode(_ type: Any.Type, to otherType: Any.Type) -> OtterError {
        return .cannotEncode("\(type)", to: "\(otherType)")
    }
}
