//
//  Schema.swift
//  Feather
//
//  Created by Wes Wickwire on 1/13/25.
//

import OrderedCollections

public struct Schema {
    public var tables: OrderedDictionary<Substring, Table> = [:]
    public var triggers: OrderedDictionary<Substring, Trigger> = [:]
    public var indices: OrderedDictionary<Substring, Index> = [:]
    
    public subscript(tableName: Substring) -> Table? {
        _read { yield tables[tableName] }
        _modify { yield &tables[tableName] }
    }
    
    public subscript(trigger triggerName: Substring) -> Trigger? {
        _read { yield triggers[triggerName] }
        _modify { yield &triggers[triggerName] }
    }
    
    public subscript(index indexName: Substring) -> Index? {
        _read { yield indices[indexName] }
        _modify { yield &indices[indexName] }
    }
}

// TODO: An ordered dictionary may not be the best representation of the
// TODO: columns. Since this is used even in selects, the user could
// TODO: technically do `SELECT foo, foo FROM bar;` which have the same
// TODO: name which the ordered dictionary wouldnt catch. Or just error?
public typealias Columns = OrderedDictionary<Substring, Type>

extension Columns {
    /// Initializes the columns with their default names that SQLite gives to them.
    init(withDefaultNames types: [Type]) {
        self = types.enumerated()
            .reduce(into: [:]) { c, v in c["column\(v.offset + 1)"] = v.element }
    }
}

/// A table within the database schema
public struct Table: Sendable {
    /// The name of the table
    public var name: Substring
    /// The columns of the table
    public var columns: Columns
    /// The columns that make up the primary key
    public let primaryKey: [Substring]
    /// What kind of table it is (FTS/CTE...)
    public let kind: Kind
    
    public enum Kind: Sendable {
        case normal
        case view
        case fts5
        case cte
    }
    
    var type: Type {
        return .row(.named(columns))
    }
}

/// A trigger to be run on certain SQL operations
public struct Trigger {
    /// The name of the trigger
    public let name: Substring
    /// The table the trigger is watching
    public let targetTable: Substring
    /// Any table accessed in the `BEGIN/END`
    public let usedTables: Set<Substring>
}

/// An index created within the schema
public struct Index {
    /// The name given too the index
    public let name: Substring
    /// The name of the table the index was created for.
    public let table: Substring
}
