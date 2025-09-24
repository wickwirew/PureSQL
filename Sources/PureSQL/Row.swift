//
//  Row.swift
//  PureSQL
//
//  Created by Wes Wickwire on 9/6/25.
//

import SQLite3

/// A raw SQLite row from a statement.
public struct Row: ~Copyable {
    @usableFromInline let sqliteStatement: OpaquePointer

    /// Decodes the column at the index as the `Value` type.
    @inlinable public func value<Value: DatabasePrimitive>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(PureSQLError) -> Value {
        return try Value(from: sqliteStatement, at: column)
    }
    
    /// Decodes the column at the index as the `Storage.Value` type
    @inlinable public func value<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        at column: Int32,
        using adapter: Coder,
        storage: Storage.Type
    ) throws(PureSQLError) -> Coder.Value {
        let storage = try Storage(from: sqliteStatement, at: column)
        return try storage.decode(from: adapter)
    }
    
    /// Decodes the column at the index as the `Storage.Value` type
    /// if it has a value.
    @inlinable public func optionalValue<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        at column: Int32,
        using adapter: Coder,
        storage: Storage.Type
    ) throws(PureSQLError) -> Coder.Value? {
        guard let storage = try Storage?(from: sqliteStatement, at: column) else { return  nil}
        return try storage.decode(from: adapter)
    }
    
    /// Decodes the struct embeeded at the start index as the `Value` type.
    @inlinable public func embedded<Value: RowDecodable>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(PureSQLError) -> Value {
        return try Value(row: self, startingAt: column)
    }
    
    /// Decodes the struct embeeded at the start index as the `Value` type
    /// if it exists
    @inlinable public func optionallyEmbedded<Value: RowDecodable>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(PureSQLError) -> Value? {
        return try Value(row: self, optionallyAt: column)
    }
    
    /// Decodes the struct embeeded at the start index as the `Value` type.
    @inlinable public func embedded<Value: RowDecodableWithAdapters>(
        at column: Int32,
        as _: Value.Type = Value.self,
        adapters: Value.Adapters
    ) throws(PureSQLError) -> Value {
        return try Value(row: self, startingAt: column, adapters: adapters)
    }
    
    /// Decodes the struct embeeded at the start index as the `Value` type
    /// if it exists
    @inlinable public func optionallyEmbedded<Value: RowDecodableWithAdapters>(
        at column: Int32,
        as _: Value.Type = Value.self,
        adapters: Value.Adapters
    ) throws(PureSQLError) -> Value? {
        return try Value(row: self, optionallyAt: column, adapters: adapters)
    }
    
    /// Whether or not the column has a non null table at the column index
    @inlinable public func hasValue(at column: Int32) -> Bool {
        sqlite3_column_type(sqliteStatement, column) != SQLITE_NULL
    }
}
