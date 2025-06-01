//
//  Schema.swift
//  Feather
//
//  Created by Wes Wickwire on 1/13/25.
//

import OrderedCollections

public struct Schema {
    public var tables: OrderedDictionary<QualifiedTableName, Table> = [:]
    public var triggers: OrderedDictionary<QualifiedTableName, Trigger> = [:]
    public var indices: OrderedDictionary<QualifiedTableName, Index> = [:]
    
    public subscript(tableName: QualifiedTableName) -> Table? {
        _read { yield tables[tableName] }
        _modify { yield &tables[tableName] }
    }
    
    public subscript(trigger triggerName: QualifiedTableName) -> Trigger? {
        _read { yield triggers[triggerName] }
        _modify { yield &triggers[triggerName] }
    }
    
    public subscript(index indexName: QualifiedTableName) -> Index? {
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
public struct Table: Sendable, Equatable {
    /// The name of the table
    public var name: QualifiedTableName
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
        case subquery
    }
    
    var type: Type {
        return .row(.fixed(columns.map(\.value)))
    }
    
    /// A table to be returned incase of an error in type checking
    static let error = Table(
        name: QualifiedTableName(name: "<<error>>", schema: nil),
        columns: [:],
        primaryKey: [],
        kind: .normal
    )
    
    /// The table but with the name of the alias.
    /// Used in `FROM foo AS bar`
    func aliased(to alias: Substring) -> Table {
        var copy = self
        // Alias erases schema on purpose.
        // main.foo AS bar does not equal main.bar
        copy.name = QualifiedTableName(name: alias, schema: nil)
        return copy
    }
    
    /// Function to map over the column types and perform any
    /// transformations needed
    func mapTypes(_ transform: (Type) -> Type) -> Table {
        var copy = self
        copy.columns = columns.mapValues(transform)
        return copy
    }
}

/// A trigger to be run on certain SQL operations
public struct Trigger {
    /// The name of the trigger
    public let name: QualifiedTableName
    /// The table the trigger is watching
    public let targetTable: QualifiedTableName
    /// Any table accessed in the `BEGIN/END`
    public let usedTables: Set<Substring>
}

/// An index created within the schema
public struct Index {
    /// The name given too the index
    public let name: QualifiedTableName
    /// The name of the table the index was created for.
    public let table: QualifiedTableName
}
