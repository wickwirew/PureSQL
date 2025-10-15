//
//  Statement.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

/// A prepared SQL statement for executing queries against the database.
///
/// `Statement` wraps a SQLite prepared statement and provides
/// methods to bind parameters, step through results, and fetch rows using
/// `RowDecodable` types or adapters. It supports single row and multi row
/// fetch operations.
public final class Statement {
    let raw: OpaquePointer
    /// When calling `bind` without an index it will bind here.
    /// This is automatically incremented
    private var currentBindIndex: Int32 = 1
    
    public enum Step {
        case row
        case done
    }
    
    public init(
        _ source: String,
        transaction: borrowing Transaction
    ) throws(SQLError) {
        self.raw = try transaction.connection.prepare(sql: source)
    }
    
    public convenience init(
        in transaction: borrowing Transaction,
        source: () -> String,
        bind: (Statement) throws -> Void = { _ in }
    ) throws {
        try self.init(source(), transaction: transaction)
        try bind(self)
    }
    
    public convenience init(in transaction: borrowing Transaction, sql: SQL) throws {
        try self.init(in: transaction) {
            sql.source
        } bind: { statement in
            for (i, parameter) in sql.parameters.enumerated() {
                try statement.bind(value: parameter, to: Int32(i + 1))
            }
        }
    }
    
    /// Binds a value to the specified index in the statement.
    public func bind<Value: DatabasePrimitive>(
        value: Value,
        to index: Int32? = nil
    ) throws(SQLError) {
        try value.bind(to: raw, at: get(index: index))
    }
    
    /// Binds a value using an adapter and storage type.
    public func bind<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        value: Coder.Value,
        to index: Int32? = nil,
        using: Coder,
        as storage: Storage.Type
    ) throws(SQLError) {
        let storage = try Storage(value: value, into: using)
        try storage.bind(to: raw, at: get(index: index))
    }
    
    /// Binds a value using an adapter and storage type.
    @_disfavoredOverload
    public func bind<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        value: Coder.Value?,
        to index: Int32? = nil,
        using: Coder,
        as storage: Storage.Type
    ) throws(SQLError) {
        
        if let value {
            let storage = try Storage(value: value, into: using)
            try storage.bind(to: raw, at: get(index: index))
        } else {
            let storage: Storage? = nil
            try storage.bind(to: raw, at: get(index: index))
        }
    }
    
    /// Steps the statement forward by one row.
    public func step() throws(SQLError) -> Step {
        let code = SQLiteCode(sqlite3_step(raw))
        switch code {
        case .sqliteDone: return .done
        case .sqliteRow: return .row
        default: throw .sqlite(code, String(cString: sqlite3_errmsg(raw)))
        }
    }
    
    private func get(index: Int32?) -> Int32 {
        if let index { return index }
        let index = currentBindIndex
        currentBindIndex += 1
        return index
    }
    
    deinit {
        sqlite3_finalize(raw)
    }
}

// MARK: - Fetch with RowDecodable

extension Statement {
    /// Fetches all rows returned by the statement
    public consuming func fetchAll<Element: RowDecodable>(
        of _: Element.Type = Element.self
    ) throws(SQLError) -> [Element] {
        var cursor = Cursor<Element>(of: self)
        var result: [Element] = []
        
        while let element = try cursor.next() {
            result.append(element)
        }
        
        return result
    }

    /// Fetches a single row returned by the statement
    public consuming func fetchOne<Element: RowDecodable>(
        of _: Element.Type = Element.self
    ) throws(SQLError) -> Element? {
        var cursor = Cursor<Element>(of: self)
        return try cursor.next()
    }
    
    /// Fetches a single row returned by the statement
    @_disfavoredOverload
    public consuming func fetchOne<Element: RowDecodable>(
        of value: Element.Type = Element.self
    ) throws(SQLError) -> Element {
        guard let row = try fetchOne(of: value) else {
            throw SQLError.queryReturnedNoValue
        }
        
        return row
    }
}

// MARK: - Fetch with RowDecodableWithAdapters

extension Statement {
    /// Fetches all rows returned by the statement
    public consuming func fetchAll<Element: RowDecodableWithAdapters>(
        of _: Element.Type = Element.self,
        adapters: Element.Adapters
    ) throws(SQLError) -> [Element] {
        var cursor = Cursor<Element>(of: self)
        var result: [Element] = []
        
        while let element = try cursor.next(adapters: adapters) {
            result.append(element)
        }
        
        return result
    }

    /// Fetches a single row returned by the statement
    public consuming func fetchOne<Element: RowDecodableWithAdapters>(
        of _: Element.Type = Element.self,
        adapters: Element.Adapters
    ) throws(SQLError) -> Element? {
        var cursor = Cursor<Element>(of: self)
        return try cursor.next(adapters: adapters)
    }
    
    /// Fetches a single row returned by the statement
    @_disfavoredOverload
    public consuming func fetchOne<Element: RowDecodableWithAdapters>(
        of value: Element.Type = Element.self,
        adapters: Element.Adapters
    ) throws(SQLError) -> Element {
        guard let row = try fetchOne(of: value, adapters: adapters) else {
            throw SQLError.queryReturnedNoValue
        }
        
        return row
    }
}

// MARK: - Fetch with specific adapter

extension Statement {
    /// Fetches all rows returned by the statement
    public consuming func fetchAll<Adapter: DatabaseValueAdapter, Storage: DatabasePrimitive>(
        of _: Adapter.Value.Type = Adapter.Value.self,
        adapter: Adapter,
        storage: Storage.Type
    ) throws(SQLError) -> [Adapter.Value] {
        var cursor = Cursor<Adapter.Value>(of: self)
        var result: [Adapter.Value] = []
        
        while let element = try cursor.next(adapter: adapter, storage: storage) {
            result.append(element)
        }
        
        return result
    }
    
    /// Fetches a single row returned by the statement
    public consuming func fetchOne<Adapter: DatabaseValueAdapter, Storage: DatabasePrimitive>(
        of _: Adapter.Value.Type = Adapter.Value.self,
        adapter: Adapter,
        storage: Storage.Type
    ) throws(SQLError) -> Adapter.Value? {
        var cursor = Cursor<Adapter.Value>(of: self)
        return try cursor.next(adapter: adapter, storage: storage)
    }
    
    /// Fetches a single row returned by the statement
    @_disfavoredOverload
    public consuming func fetchOne<Adapter: DatabaseValueAdapter, Storage: DatabasePrimitive>(
        of value: Adapter.Value.Type = Adapter.Value.self,
        adapter: Adapter,
        storage: Storage.Type
    ) throws(SQLError) -> Adapter.Value {
        guard let row = try fetchOne(of: value, adapter: adapter, storage: storage) else {
            throw SQLError.queryReturnedNoValue
        }
        
        return row
    }
}
