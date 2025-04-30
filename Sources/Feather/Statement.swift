//
//  Statement.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

public struct Statement: ~Copyable {
    let raw: OpaquePointer
    private var bindIndex: Int32 = 1
    
    public enum Step {
        case row
        case done
    }
    
    public init(
        _ source: String,
        transaction: borrowing Transaction
    ) throws(FeatherError) {
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
    ) throws(FeatherError) {
        try value.bind(to: raw, at: index)
    }
    
    public mutating func bind<Value: DatabasePrimitive>(
        value: Value
    ) throws(FeatherError) {
        try bind(value: value, to: bindIndex)
        bindIndex += 1
    }
    
    public func step() throws(FeatherError) -> Step {
        let code = SQLiteCode(sqlite3_step(raw))
        switch code {
        case .sqliteDone: return .done
        case .sqliteRow: return .row
        default: throw .sqlite(code, String(cString: sqlite3_errmsg(raw)))
        }
    }
    
    /// Fetches all rows returned by the statement
    public consuming func fetchAll<Element: RowDecodable>(
        of _: Element.Type
    ) throws(FeatherError) -> [Element] {
        var cursor = Cursor<Element>(of: self)
        var result: [Element] = []
        
        while let element = try cursor.next() {
            result.append(element)
        }
        
        return result
    }
    
    /// Fetches all rows returned by the statement
    public consuming func fetchOne<T: RowDecodable>(
        of _: T.Type
    ) throws(FeatherError) -> T? {
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
