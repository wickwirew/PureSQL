//
//  SQLAny.swift
//  PureSQL
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
        case let .string(string): string
        case let .int(int): int.description
        case let .double(double): double.description
        case let .data(data): data.description
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
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError) {
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

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError) {
        switch self {
        case let .string(string): try string.bind(to: statement, at: index)
        case let .int(int): try int.bind(to: statement, at: index)
        case let .double(double): try double.bind(to: statement, at: index)
        case let .data(data): try data.bind(to: statement, at: index)
        }
    }
    
    @inlinable public init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError) {
        self = try adapter.encodeToAny(value: value)
    }
    
    @inlinable public func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value {
        try adapter.decode(from: self)
    }
    
    public var sqlAny: SQLAny? { self }
}
