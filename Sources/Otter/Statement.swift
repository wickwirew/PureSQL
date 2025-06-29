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
        var raw: OpaquePointer?
        try throwing(
            sqlite3_prepare_v2(transaction.connection.sqliteConnection, source, -1, &raw, nil),
            connection: transaction.connection.sqliteConnection
        )
        
        guard let raw else {
            throw .failedToInitializeStatement
        }
        
        self.raw = raw
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
        using: Coder.Type,
        as storage: Storage.Type
    ) throws(OtterError) {
        let storage = try Storage(value: value, into: using)
        try storage.bind(to: raw, at: index)
    }
    
    @_disfavoredOverload
    public func bind<Storage: DatabasePrimitive, Coder: DatabaseValueAdapter>(
        value: Coder.Value?,
        to index: Int32,
        using: Coder.Type,
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
    
    /// Fetches all rows returned by the statement
    public consuming func fetchAll<Element: RowDecodable>() throws(OtterError) -> [Element] {
        return try fetchAll(of: Element.self)
    }
    
    /// Fetches all rows returned by the statement
    public consuming func fetchAll<Element: RowDecodable>(
        of _: Element.Type
    ) throws(OtterError) -> [Element] {
        var cursor = Cursor<Element>(of: self)
        var result: [Element] = []
        
        while let element = try cursor.next() {
            result.append(element)
        }
        
        return result
    }
    
    /// Fetches a single row returned by the statement
    public consuming func fetchOne<T: RowDecodable>() throws(OtterError) -> T? {
        return try fetchOne(of: T.self)
    }
    
    /// Fetches a single row returned by the statement
    public consuming func fetchOne<T: RowDecodable>(
        of _: T.Type
    ) throws(OtterError) -> T? {
        var cursor = Cursor<T>(of: self)
        return try cursor.next()
    }
    
    deinit {
        do {
            try throwing(sqlite3_finalize(raw))
        } catch {
            fatalError("Failed to finalize statement: \(error)")
        }
    }
}
