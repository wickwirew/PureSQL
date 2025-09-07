//
//  TestUtils.swift
//  Otter
//
//  Created by Wes Wickwire on 9/6/25.
//

@testable import Otter

/// Useful test helper that creates an in memory SQLiite database.
/// It will run the migrations, then the query and give a `Cursor<()>` back.
/// The cursor is of void so custom decoding can be attempted without
/// worrying about creating different `RowDecodable` types
func withCursor(
    migrations: () -> String,
    query: () -> SQL,
    operation: (inout Cursor<()>) throws -> Void
) throws {
    try withStatement(migrations: migrations, query: query) { stmt in
        var cursor = Cursor<()>(of: stmt)
        try operation(&cursor)
    }
}

/// Useful test helper that creates an in memory SQLiite database.
/// It will run the migrations, then the query and give a `Statement` back.
func withStatement(
    migrations: () -> String,
    query: () -> SQL,
    operation: (consuming Statement) throws -> Void
) throws {
    let connection = try SQLiteConnection(path: ":memory:")
    try connection.execute(sql: migrations())
    let tx = try Transaction(connection: connection, kind: .read)
    let stmt = try Statement(in: tx, sql: query())
    try operation(stmt)
    try tx.commit()
}
