//
//  Cursor.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

public struct Cursor: ~Copyable {
    private let statement: Statement
    private var column: Int32 = 0
    
    public init(of statement: consuming Statement) {
        self.statement = statement
    }
    
    public func indexedColumns() -> IndexedColumns {
        return IndexedColumns(statement.raw)
    }
    
    public mutating func step() throws(FeatherError) -> Bool {
        let code = SQLiteCode(sqlite3_step(statement.raw))
        
        switch code {
        case .sqliteDone:
            return false
        case .sqliteRow:
            return true
        default:
            throw .sqlite(code)
        }
    }
}

public extension Cursor {
    /// A method of decoding columns. The fastest way
    /// to read the columns out of a select is in order.
    struct IndexedColumns: ~Copyable {
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
