//
//  Statement.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

public struct Statement: ~Copyable {
    let raw: OpaquePointer
    
    public enum Step {
        case row
        case done
    }
    
    public init(
        _ source: String,
        transaction: borrowing Transaction
    ) throws(OtterError) {
        self.raw = try transaction.connection.prepare(sql: source)
    }
    
    public init(
        in transaction: borrowing Transaction,
        source: () -> String,
        bind: (inout Statement) throws -> Void = { _ in }
    ) throws {
        var statement = try Statement(source(), transaction: transaction)
        try bind(&statement)
        self = statement
    }
    
    public init(in transaction: borrowing Transaction, sql: SQL) throws {
        self = try Statement(in: transaction) {
            sql.source
        } bind: { statement in
            for (i, parameter) in sql.parameters.enumerated() {
                try statement.bind(value: parameter, to: Int32(i + 1))
            }
        }
    }
    
    public func bind<Value: DatabasePrimitive>(
        value: Value,
        to index: Int32
    ) throws(OtterError) {
        try value.bind(to: raw, at: index)
    }
    
    public func bind<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        value: Coder.Value,
        to index: Int32,
        using: Coder,
        as storage: Storage.Type
    ) throws(OtterError) {
        let storage = try Storage(value: value, into: using)
        try storage.bind(to: raw, at: index)
    }
    
    @_disfavoredOverload
    public func bind<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        value: Coder.Value?,
        to index: Int32,
        using: Coder,
        as storage: Storage.Type
    ) throws(OtterError) {
        if let value {
            let storage = try Storage(value: value, into: using)
            try storage.bind(to: raw, at: index)
        } else {
            let storage: Storage? = nil
            try storage.bind(to: raw, at: index)
        }
    }
    
    public func step() throws(OtterError) -> Step {
        let code = SQLiteCode(sqlite3_step(raw))
        switch code {
        case .sqliteDone: return .done
        case .sqliteRow: return .row
        default: throw .sqlite(code, String(cString: sqlite3_errmsg(raw)))
        }
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
    ) throws(OtterError) -> [Element] {
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
    ) throws(OtterError) -> Element? {
        var cursor = Cursor<Element>(of: self)
        return try cursor.next()
    }
    
    /// Fetches a single row returned by the statement
    @_disfavoredOverload
    public consuming func fetchOne<Element: RowDecodable>(
        of value: Element.Type = Element.self
    ) throws(OtterError) -> Element {
        guard let row = try fetchOne(of: value) else {
            throw OtterError.queryReturnedNoValue
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
    ) throws(OtterError) -> [Element] {
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
    ) throws(OtterError) -> Element? {
        var cursor = Cursor<Element>(of: self)
        return try cursor.next(adapters: adapters)
    }
    
    /// Fetches a single row returned by the statement
    @_disfavoredOverload
    public consuming func fetchOne<Element: RowDecodableWithAdapters>(
        of value: Element.Type = Element.self,
        adapters: Element.Adapters
    ) throws(OtterError) -> Element {
        guard let row = try fetchOne(of: value, adapters: adapters) else {
            throw OtterError.queryReturnedNoValue
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
    ) throws(OtterError) -> [Adapter.Value] {
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
    ) throws(OtterError) -> Adapter.Value? {
        var cursor = Cursor<Adapter.Value>(of: self)
        return try cursor.next(adapter: adapter, storage: storage)
    }
    
    /// Fetches a single row returned by the statement
    @_disfavoredOverload
    public consuming func fetchOne<Adapter: DatabaseValueAdapter, Storage: DatabasePrimitive>(
        of value: Adapter.Value.Type = Adapter.Value.self,
        adapter: Adapter,
        storage: Storage.Type
    ) throws(OtterError) -> Adapter.Value {
        guard let row = try fetchOne(of: value, adapter: adapter, storage: storage) else {
            throw OtterError.queryReturnedNoValue
        }
        
        return row
    }
}
