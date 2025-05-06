//
//  DatabasePrimitive.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import SQLite3
import Foundation

@usableFromInline let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

extension UInt: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        self = try UInt(bitPattern: Int(from: cursor, at: index))
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        sqlite3_bind_int(statement, index, Int32(bitPattern: UInt32(self)))
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

extension Float: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        self = Float(sqlite3_column_double(cursor, index))
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        sqlite3_bind_double(statement, index, Double(self))
    }
}

extension Bool: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        self = sqlite3_column_int64(cursor, index) == 1
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        sqlite3_bind_int(statement, index, self ? 1 : 0)
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

extension UUID: DatabasePrimitive {
    @inlinable public init(from cursor: OpaquePointer, at index: Int32) throws(FeatherError) {
        guard let ptr = sqlite3_column_text(cursor, index) else {
            throw .columnIsNil(index)
        }

        guard let value = UUID(uuidString: String(cString: ptr)) else {
            throw .invalidUuidString
        }
        
        self = value
    }

    @inlinable public func bind(to statement: OpaquePointer, at index: Int32) throws(FeatherError) {
        try uuidString.bind(to: statement, at: index)
    }
}
