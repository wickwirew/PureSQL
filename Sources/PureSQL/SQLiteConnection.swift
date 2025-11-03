//
//  SQLiteConnection.swift
//  PureSQL
//
//  Created by Wes Wickwire on 11/9/24.
//

import Collections
import Foundation
import SQLite3

/// Represents a raw connection to the SQLite database
public protocol RawConnection: Sendable {
    /// Initializes a SQLite prepared statement
    func prepare(sql: String) throws(SQLError) -> OpaquePointer
    /// Executes the SQL statement.
    /// Equivalent to `sqlite3_exec`
    func execute(sql: String) throws(SQLError)
}

/// Holds a raw SQLite database connection.
/// `@unchecked Sendable` Thread safety is managed by
/// the `ConnectionPool`
class SQLiteConnection: RawConnection, @unchecked Sendable {
    let sqliteConnection: OpaquePointer

    init(
        path: String,
        flags: Int32 = SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_NOMUTEX
            | SQLITE_OPEN_URI
    ) throws(SQLError) {
        var raw: OpaquePointer?
        try throwing(sqlite3_open_v2(path, &raw, flags, nil))

        guard let raw else {
            throw .failedToOpenConnection(path: path)
        }

        self.sqliteConnection = raw
    }
    
    func prepare(sql: String) throws(SQLError) -> OpaquePointer {
        var raw: OpaquePointer?
        try throwing(
            sqlite3_prepare_v2(sqliteConnection, sql, -1, &raw, nil),
            connection: sqliteConnection
        )
        
        guard let raw else {
            throw .failedToInitializeStatement
        }
        
        return raw
    }

    func execute(sql: String) throws(SQLError) {
        var error: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(sqliteConnection, sql, nil, nil, &error)
        
        if rc == SQLITE_OK {
            return
        }
        
        var message: String?
        if let error {
            message = String(cString: error)
            sqlite3_free(error)
        }
        
        throw .sqlite(SQLiteCode(rc), message)
    }

    deinit {
        do {
            try throwing(sqlite3_close_v2(sqliteConnection))
        } catch {
            assertionFailure("Failed to close connection: \(error)")
        }
    }
}

final class NoopRawConnection: RawConnection {
    func execute(sql: String) throws(SQLError) {}
    func prepare(sql: String) throws(SQLError) -> OpaquePointer {
        throw .failedToGetConnection
    }
}
