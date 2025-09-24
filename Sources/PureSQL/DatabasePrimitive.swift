//
//  DatabasePrimitive.swift
//  PureSQL
//
//  Created by Wes Wickwire on 11/9/24.
//

import Foundation
import SQLite3

@usableFromInline let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A type that is mapped directly to a SQLite type.
///
/// You **should not** be conforming any of your types to this directly.
/// It will have no effect. For custom type conversion see `DatabasePrimitiveConvertible`
public protocol DatabasePrimitive: RowDecodable {
    /// This value as an `ANY`
    var sqlAny: SQLAny? { get }
    
    /// Initialize from the row at the column `index`
    init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError)
    
    /// Initializes self using the `adapter`
    init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError)
    
    /// Bind self to the statement at the given parameter index
    func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError)
    
    /// Decode self using the `adapter`
    func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value
}

public extension DatabasePrimitive {
    init(row: borrowing Row, startingAt start: Int32) throws(PureSQLError) {
        self = try row.value(at: start)
    }
}

extension String: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError) {
        guard let ptr = sqlite3_column_text(cursor, index) else {
            throw PureSQLError.columnIsNil(index)
        }

        self = String(cString: ptr)
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError) {
        sqlite3_bind_text(statement, index, self, -1, SQLITE_TRANSIENT)
    }
    
    @inlinable public init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError) {
        self = try adapter.encodeToString(value: value)
    }
    
    @inlinable public func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value {
        try adapter.decode(from: self)
    }
    
    @inlinable public var sqlAny: SQLAny? { .string(self) }
}

extension Int: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError) {
        self = Int(sqlite3_column_int64(cursor, index))
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError) {
        sqlite3_bind_int(statement, index, Int32(self))
    }
    
    @inlinable public init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError) {
        self = try adapter.encodeToInt(value: value)
    }
    
    @inlinable public func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value {
        try adapter.decode(from: self)
    }
    
    @inlinable public var sqlAny: SQLAny? { .int(self) }
}

extension Double: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError) {
        self = sqlite3_column_double(cursor, index)
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError) {
        sqlite3_bind_double(statement, index, self)
    }
    
    @inlinable public init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError) {
        self = try adapter.encodeToDouble(value: value)
    }
    
    @inlinable public func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value {
        try adapter.decode(from: self)
    }
    
    @inlinable public var sqlAny: SQLAny? { .double(self) }
}

extension Data: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError) {
        let count = Int(sqlite3_column_bytes(cursor, index))
        self = Data(bytes: sqlite3_column_blob(cursor, index), count: count)
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError) {
        _ = withUnsafeBytes {
            sqlite3_bind_blob(statement, index, $0.baseAddress, CInt($0.count), SQLITE_TRANSIENT)
        }
    }
    
    @inlinable public init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError) {
        self = try adapter.encodeToData(value: value)
    }
    
    @inlinable public func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value {
        try adapter.decode(from: self)
    }
    
    @inlinable public var sqlAny: SQLAny? { .data(self) }
}

extension Optional: DatabasePrimitive where Wrapped: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(PureSQLError) {
        if sqlite3_column_type(cursor, index) == SQLITE_NULL {
            self = nil
        } else {
            self = try Wrapped(from: cursor, at: index)
        }
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(PureSQLError) {
        if let value = self {
            try value.bind(to: statement, at: index)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    @inlinable public init<Adapter: DatabaseValueAdapter>(
        value: Adapter.Value,
        into adapter: Adapter
    ) throws(PureSQLError) {
        self = try .some(Wrapped(value: value, into: adapter))
    }
    
    @inlinable public func decode<Adapter: DatabaseValueAdapter>(
        from adapter: Adapter
    ) throws(PureSQLError) -> Adapter.Value {
        guard let value = self else {
            assertionFailure("Upstream did not perform nil check")
            throw .unexpectedNil
        }
        return try value.decode(from: adapter)
    }
    
    @inlinable public var sqlAny: SQLAny? {
        self?.sqlAny
    }
}
