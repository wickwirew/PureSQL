//
//  Connection.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import SQLite3

public struct Transaction: ~Copyable {
    private let connection: Connection
}

public struct Connection {
    var raw: OpaquePointer
    
    // SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
    
    public init(path: String, flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI) throws(FeatherError) {
        var raw: OpaquePointer?
        try throwing(sqlite3_open_v2(path, &raw, flags, nil))
        
        guard let raw else {
            throw .failedToOpenConnection(path: path)
        }
        
        self.raw = raw
    }
    
    public consuming func close() throws(FeatherError) {
        try throwing(sqlite3_close_v2(raw))
    }
}

public enum FeatherError: Error {
    case failedToOpenConnection(path: String)
    case failedToInitializeStatement
    case columnIsNil(Int32)
    case noMoreColumns
    case queryReturnedNoValue
    case sqlite(SQLiteCode)
}
public protocol RowDecodable {
    init(cursor: borrowing Cursor) throws(FeatherError)
}

public struct Statement: ~Copyable {
    public let source: String
    let raw: OpaquePointer
    private var bindIndex: Int32 = 0
    
    public init(
        _ source: String,
        connection: borrowing Connection
    ) throws(FeatherError) {
        self.source = source
        var raw: OpaquePointer?
        try throwing(sqlite3_prepare_v2(connection.raw, source, -1, &raw, nil))
        
        guard let raw else {
            throw .failedToInitializeStatement
        }
        
        self.raw = raw
    }
    
    public mutating func bind<Value: DatabasePrimitive>(value: Value) throws(FeatherError) {
        try value.bind(to: raw, at: bindIndex)
        bindIndex += 1
    }
}

public struct Cursor: ~Copyable {
    private var raw: OpaquePointer
    private var column: Int32 = 0
    
    public init(of statement: consuming Statement) {
        self.raw = statement.raw
    }
    
    public func indexedColumns() -> IndexedColumns {
        return IndexedColumns(raw)
    }
    
    public mutating func step() throws(FeatherError) -> Bool {
        let code = SQLiteCode(sqlite3_step(raw))
        
        switch code {
        case .sqliteDone:
            return false
        case .sqliteRow:
            return true
        default:
            throw .sqlite(code)
        }
    }
    
    deinit {
        do {
            try throwing(sqlite3_finalize(raw))
        } catch {
            fatalError("Failed to finalize statement: \(error)")
        }
    }
}

extension Cursor {
    /// A method of decoding columns. The fastest way
    /// to read the columns out of a select is in order.
    public struct IndexedColumns: ~Copyable {
        @usableFromInline var raw: OpaquePointer
        @usableFromInline var column: Int32 = 0
        @usableFromInline let count: Int32
        
        init(_ raw: OpaquePointer) {
            self.raw = raw
            self.count = sqlite3_column_count(raw)
        }
        
        @inlinable public mutating func next<Value: DatabasePrimitive>() throws(FeatherError) -> Value {
            guard column < count else {
                throw .noMoreColumns
            }
            
            let value = try Value(from: raw, at: column)
            column += 1
            return value
        }
    }
}
