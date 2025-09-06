//
//  Cursor.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

public struct Cursor<Element>: ~Copyable {
    private let statement: Statement

    public init(of statement: consuming Statement) {
        self.statement = statement
    }
}

extension Cursor where Element: RowDecodable {
    public mutating func next() throws(OtterError) -> Element? {
        switch try statement.step() {
        case .row:
            let row = Row(sqliteStatement: statement.raw)
            return try Element(row: row, startingAt: 0)
        case .done:
            return nil
        }
    }
}

extension Cursor where Element: RowDecodableWithAdapters {
    public mutating func next(adapters: Element.Adapters) throws(OtterError) -> Element? {
        switch try statement.step() {
        case .row:
            let row = Row(sqliteStatement: statement.raw)
            return try Element(row: row, startingAt: 0, adapters: adapters)
        case .done:
            return nil
        }
    }
}

public struct Row: ~Copyable {
    @usableFromInline let sqliteStatement: OpaquePointer

    /// Decodes the column at the index as the `Value` type.
    @inlinable public func value<Value: DatabasePrimitive>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(OtterError) -> Value {
        return try Value(from: sqliteStatement, at: column)
    }
    
    /// Decodes the column at the index as the `Storage.Value` type
    @inlinable public func value<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        at column: Int32,
        using adapter: Coder,
        storage: Storage.Type
    ) throws(OtterError) -> Coder.Value {
        let storage = try Storage(from: sqliteStatement, at: column)
        return try storage.decode(from: adapter)
    }
    
    /// Decodes the column at the index as the `Storage.Value` type
    /// if it has a value.
    @inlinable public func optionalValue<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        at column: Int32,
        using adapter: Coder,
        storage: Storage.Type
    ) throws(OtterError) -> Coder.Value? {
        guard let storage = try Storage?(from: sqliteStatement, at: column) else { return  nil}
        return try storage.decode(from: adapter)
    }
    
    /// Decodes the struct embeeded at the start index as the `Value` type.
    @inlinable public func embedded<Value: RowDecodable>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(OtterError) -> Value {
        return try Value(row: self, startingAt: column)
    }
    
    /// Decodes the struct embeeded at the start index as the `Value` type
    /// if it exists
    @inlinable public func optionallyEmbedded<Value: RowDecodable>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(OtterError) -> Value? {
        return try Value(row: self, optionallyAt: column)
    }
    
    /// Whether or not the column has a non null table at the column index
    @inlinable public func hasValue(at column: Int32) -> Bool {
        sqlite3_column_type(sqliteStatement, column) != SQLITE_NULL
    }
}
