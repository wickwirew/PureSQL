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
    @usableFromInline let sqliteStatement: OpaquePointer
    
    @inlinable public func value<Value: DatabasePrimitive>(
        at column: Int32,
        as _: Value.Type = Value.self
    ) throws(FeatherError) -> Value {
        return try Value(from: sqliteStatement, at: column)
    }
}
