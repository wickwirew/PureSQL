//
//  Cursor.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

/// A low-level iterator over the results of a prepared database statement.
///
/// `Cursor` wraps a `Statement` and allows stepping through query results one
/// row at a time. Use `next()` functions to get the next row in the iteration.
public struct Cursor<Element>: ~Copyable {
    private let statement: Statement

    public init(of statement: consuming Statement) {
        self.statement = statement
    }
    
    public mutating func nextRow() throws(PureSQLError) -> Row? {
        switch try statement.step() {
        case .row: Row(sqliteStatement: statement.raw)
        case .done: nil
        }
    }
    
    public mutating func next<Adapter: DatabaseValueAdapter, Storage: DatabasePrimitive>(
        adapter: Adapter,
        storage: Storage.Type
    ) throws(PureSQLError) -> Element? where Adapter.Value == Element {
        switch try statement.step() {
        case .row:
            let row = Row(sqliteStatement: statement.raw)
            return try row.value(at: 0, using: adapter, storage: storage)
        case .done:
            return nil
        }
    }
}

extension Cursor where Element: RowDecodable {
    public mutating func next() throws(PureSQLError) -> Element? {
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
    public mutating func next(adapters: Element.Adapters) throws(PureSQLError) -> Element? {
        switch try statement.step() {
        case .row:
            let row = Row(sqliteStatement: statement.raw)
            return try Element(row: row, startingAt: 0, adapters: adapters)
        case .done:
            return nil
        }
    }
}
