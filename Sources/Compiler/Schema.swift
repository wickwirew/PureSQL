//
//  Schema.swift
//  PureSQL
//
//  Created by Wes Wickwire on 1/13/25.
//

import OrderedCollections

public struct Schema {
    public var tables: OrderedDictionary<QualifiedName, Table> = [:]
    public var triggers: OrderedDictionary<QualifiedName, Trigger> = [:]
    public var indices: OrderedDictionary<QualifiedName, Index> = [:]

    public subscript(tableName: QualifiedName) -> Table? {
        _read { yield tables[tableName] }
        _modify { yield &tables[tableName] }
    }

    public subscript(trigger triggerName: QualifiedName) -> Trigger? {
        _read { yield triggers[triggerName] }
        _modify { yield &triggers[triggerName] }
    }

    public subscript(index indexName: QualifiedName) -> Index? {
        _read { yield indices[indexName] }
        _modify { yield &indices[indexName] }
    }
}
