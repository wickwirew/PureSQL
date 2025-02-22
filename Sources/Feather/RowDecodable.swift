//
//  RowDecodable.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public protocol RowDecodable {
    init(row: borrowing Row) throws(FeatherError)
}

extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public init(row: borrowing Row) throws(FeatherError) {
        var columns = row.columnIterator()
        self = try columns.next()
    }
}
