//
//  RowDecodable.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

public protocol RowDecodable {
    init(row: borrowing Row, startingAt column: Int32) throws(FeatherError)
}

extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public init(row: borrowing Row, startingAt start: Int32) throws(FeatherError) {
        self = try row.value(at: start)
    }
}
