//
//  SQLAny.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

import Foundation
import SQLite3

/// SQLite supports an `ANY` type. Mapping to a `Swift.Any` would
/// not be a smart idea and would not implement things like
/// `Hashable` and `Sendable`. This wraps any possible value that
/// SQLite can throw at us.
///
/// SQLite type can be `NULL` but that is not acknowledged here
/// and nullability is handled at the constraint level like
/// every other type.
public enum SQLAny: Sendable, Hashable {
    /// Maps to `TEXT`
    case string(String)
    /// Maps to `INTEGER` and `INT`
    case int(Int)
    /// Maps to `REAL`
    case double(Double)
    /// Maps to `BLOB`
    case data(Data)
    
    /// The value if it is a `.string`
    public var string: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
    
    /// The value if it is a `.int`
    public var int: Int? {
        guard case let .int(value) = self else { return nil }
        return value
    }
    
    /// The value if it is a `.double`
    public var double: Double? {
        guard case let .double(value) = self else { return nil }
        return value
    }
    
    /// The value if it is a `.data`
    public var data: Data? {
        guard case let .data(value) = self else { return nil }
        return value
    }
}

extension SQLAny: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let string): string
        case .int(let int): int.description
        case .double(let double): double.description
        case .data(let data): data.description
        }
    }
}

extension SQLAny: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension SQLAny: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }
}

extension SQLAny: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}

extension SQLAny: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        let type = sqlite3_column_type(cursor, index)
        switch type {
        case SQLITE_TEXT: self = try .string(String(from: cursor, at: index))
        case SQLITE_INTEGER: self = try .int(Int(from: cursor, at: index))
        case SQLITE_FLOAT: self = try .double(Double(from: cursor, at: index))
        case SQLITE_BLOB: self = try .data(Data(from: cursor, at: index))
        case SQLITE_NULL: throw .decodingError("Expected non nil value for `ANY` column type")
        default: fatalError("Unknown column type code: \(type)")
        }
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        switch self {
        case .string(let string): try string.bind(to: statement, at: index)
        case .int(let int): try int.bind(to: statement, at: index)
        case .double(let double): try double.bind(to: statement, at: index)
        case .data(let data): try data.bind(to: statement, at: index)
        }
    }
}
