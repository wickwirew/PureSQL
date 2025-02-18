//
//  Statement.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SQLite3

public struct Statement: ~Copyable {
    let raw: OpaquePointer
    
    public init(
        _ source: String,
        transaction: borrowing Transaction
    ) throws(FeatherError) {
        var raw: OpaquePointer?
        try throwing(
            sqlite3_prepare_v2(transaction.connection.raw, source, -1, &raw, nil),
            connection: transaction.connection.raw
        )
        
        guard let raw else {
            throw .failedToInitializeStatement
        }
        
        self.raw = raw
    }
    
    public init(
        in transaction: borrowing Transaction,
        source: () -> String,
        bind: (inout Statement) throws -> Void = { _ in }
    ) throws {
        var statement = try Statement(source(), transaction: transaction)
        try bind(&statement)
        self = statement
    }
    
    public mutating func bind<Value: DatabasePrimitive>(
        value: Value,
        to index: Int32
    ) throws(FeatherError) {
        try value.bind(to: raw, at: index)
    }
    
    deinit {
        do {
            try throwing(sqlite3_finalize(raw))
        } catch {
            fatalError("Failed to finalize statement: \(error)")
        }
    }
}
