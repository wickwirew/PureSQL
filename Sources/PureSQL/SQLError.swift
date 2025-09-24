//
//  SQLError.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/16/25.
//

import Foundation

public enum SQLError: Error, Equatable {
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
    ) -> SQLError {
        return .cannotDecode("\(type)", from: "\(otherType)", reason: reason)
    }

    public static func cannotEncode(
        _ type: Any.Type,
        to otherType: Any.Type,
        reason: String? = nil
    ) -> SQLError {
        return .cannotEncode("\(type)", to: "\(otherType)", reason: reason)
    }
}

extension SQLError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .failedToOpenConnection(let path):
            return "Failed to open database connection at path '\(path)'."
        case .failedToInitializeStatement:
            return "Failed to initialize SQL statement."
        case .columnIsNil(let index):
            return "Column at index \(index) is nil."
        case .noMoreColumns:
            return "No more columns available in the row."
        case .queryReturnedNoValue:
            return "Query returned no value."
        case .sqlite(let code, let message):
            if let message = message {
                return "SQLite error \(code): \(message)"
            } else {
                return "SQLite error \(code)"
            }
        case .txNoLongerValid:
            return "Transaction is no longer valid."
        case .failedToGetConnection:
            return "Failed to get a connection from the pool."
        case .poolCannotHaveZeroConnections:
            return "Connection pool cannot have zero connections."
        case .alreadyCommited:
            return "Transaction has already been committed."
        case .entityWasNotFound:
            return "Requested entity was not found."
        case .subscriptionAlreadyStarted:
            return "Query observation has already been started."
        case .invalidUuidString:
            return "Invalid UUID string."
        case .cannotDecode(let type, let from, let reason):
            if let reason = reason {
                return "Cannot decode \(type) from \(from): \(reason)"
            } else {
                return "Cannot decode \(type) from \(from)."
            }
        case .cannotEncode(let type, let to, let reason):
            if let reason = reason {
                return "Cannot encode \(type) to \(to): \(reason)"
            } else {
                return "Cannot encode \(type) to \(to)."
            }
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .requiredAssociationFailed(let parent, let childKey):
            return "Required association failed: \(parent).\(childKey)"
        case .cannotObserveWriteQuery:
            return "Cannot observe a write query."
        case .cannotWriteInAReadTransaction:
            return "Cannot perform a write in a read-only transaction."
        case .unexpectedNil:
            return "Unexpected nil encountered."
        }
    }
}

extension SQLError: LocalizedError {
    public var errorDescription: String? { description }
}
