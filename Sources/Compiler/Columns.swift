//
//  Columns.swift
//  Feather
//
//  Created by Wes Wickwire on 6/2/25.
//

import OrderedCollections

public typealias Columns = OrderedDictionary<Substring, Type>

extension Columns {
    /// Initializes the columns with their default names that SQLite gives to them.
    init(withDefaultNames types: [Type]) {
        self = types.enumerated()
            .reduce(into: [:]) { c, v in c["column\(v.offset + 1)"] = v.element }
    }
}
