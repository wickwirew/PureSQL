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
            .reduce(into: [:]) { c, v in c["column\(v.offset)"] = v.element }
    }
}

public struct Table: Sendable {
    public var name: Substring
    public var columns: Columns
    public let primaryKey: [Substring]
    public let kind: Kind
    
    public enum Kind: Sendable {
        case normal
        case view
        case fts5
    }
    
    var type: Type {
        return .row(.named(columns))
    }
}

public struct Trigger {
    /// The name of the trigger
    public let name: Substring
    /// The table the trigger is watching
    public let targetTable: Substring
    /// Any table accessed in the `BEGIN/END`
    public let usedTables: Set<Substring>
}

public struct Index {
    public let name: Substring
    public let table: Substring
}
