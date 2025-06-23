//
//  RowDecodable.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

public protocol RowDecodable {
    init(row: borrowing Row, startingAt start: Int32) throws(OtterError)
}

extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public init(row: borrowing Row, startingAt start: Int32) throws(OtterError) {
        self = try row.value(at: start)
    }
}
