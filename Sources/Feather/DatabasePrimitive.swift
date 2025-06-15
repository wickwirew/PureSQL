//
//  DatabasePrimitive.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import SQLite3
import Foundation

@usableFromInline let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A type that is mapped directly to a SQLite type.
///
/// You **should not** be conforming any of your types to this directly.
/// It will have no effect. For custom type conversion see `DatabasePrimitiveConvertible`
public protocol DatabasePrimitive: RowDecodable {
    init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError)
    func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError)
}

extension DatabasePrimitive {
    public init(row: borrowing Row, startingAt start: Int32) throws(FeatherError) {
        self = try row.value(at: start)
    }
}

extension String: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        guard let ptr = sqlite3_column_text(cursor, index) else {
            throw FeatherError.columnIsNil(index)
        }

        self = String(cString: ptr)
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        sqlite3_bind_text(statement, index, self, -1, SQLITE_TRANSIENT)
    }
}

extension Int: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        self = Int(sqlite3_column_int64(cursor, index))
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        sqlite3_bind_int(statement, index, Int32(self))
    }
}

extension Double: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        self = sqlite3_column_double(cursor, index)
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        sqlite3_bind_double(statement, index, self)
    }
}

extension Data: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        let count = Int(sqlite3_column_bytes(cursor, index))
        self = Data(bytes: sqlite3_column_blob(cursor, index), count: count)
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        _ = withUnsafeBytes {
            sqlite3_bind_blob(statement, index, $0.baseAddress, CInt($0.count), SQLITE_TRANSIENT)
        }
    }
}

extension Optional: DatabasePrimitive where Wrapped: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        if sqlite3_column_type(cursor, index) == SQLITE_NULL {
            self = nil
        } else {
            self = try Wrapped(from: cursor, at: index)
        }
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        if let value = self {
            try value.bind(to: statement, at: index)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
}
