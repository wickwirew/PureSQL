//
//  Schema.swift
//  Feather
//
//  Created by Wes Wickwire on 1/13/25.
//

import OrderedCollections

public typealias Schema = OrderedDictionary<Substring, Table>

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

public struct Table {
    public var name: Substring
    public var columns: Columns
    public let primaryKey: [Substring]
    public let kind: Kind
    
    public enum Kind {
        case normal
        case view
        case fts5
    }
    
    var type: Type {
        return .row(.named(columns))
    }
}
