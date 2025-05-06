//
//  Cursor.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

public struct Cursor<Element: RowDecodable>: ~Copyable {
    private let statement: Statement
    private var column: Int32 = 0
    
    public init(of statement: consuming Statement) {
        self.statement = statement
    }
    
    public mutating func next() throws(FeatherError) -> Element? {
        switch try statement.step() {
        case .row:
            let row = Row(sqliteStatement: statement.raw)
            return try Element(row: row, startingAt: 0)
        case .done:
            return nil
        }
    }
}

public struct Row: ~Copyable {
    let sqliteStatement: OpaquePointer
    
    public func value<Value: DatabasePrimitive>(at column: Int32) throws(FeatherError) -> Value {
        return try Value(from: sqliteStatement, at: column)
    }
    
    /// Gets an interator to enumerate all of the columns for the `Row`
    public func columnIterator() -> ColumnIterator {
        return ColumnIterator(sqliteStatement)
    }
    
    /// Will iterate over the columns. Returning the next column
    /// in the row. Starts at column 0.
    public struct ColumnIterator: ~Copyable {
        @usableFromInline var sqliteStatement: OpaquePointer
        /// The next column index to read. These indices start
        /// with 0, unlike bind params starting at 1
        @usableFromInline var column: Int32 = 0
        @usableFromInline let count: Int32
        
        init(_ sqliteStatement: OpaquePointer) {
            self.sqliteStatement = sqliteStatement
            self.count = sqlite3_column_count(sqliteStatement)
        }
        
        @inlinable public mutating func next<Value: DatabasePrimitive>() throws(FeatherError) -> Value {
            guard column < count else {
                throw .noMoreColumns
            }
            
            let value = try Value(from: sqliteStatement, at: column)
            column += 1
            return value
        }
    }
}
