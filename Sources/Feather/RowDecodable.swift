//
//  RowDecodable.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public protocol RowDecodable {
    init(cursor: borrowing Cursor) throws(FeatherError)
}

extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public init(cursor: borrowing Cursor) throws(FeatherError) {
        var columns = cursor.indexedColumns()
        self = try columns.next()
    }
}
