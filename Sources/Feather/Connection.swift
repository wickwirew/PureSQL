//
//  Connection.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import Collections
import SQLite3
import Foundation

/// Holds a raw SQLite database connection.
/// `@unchecked Sendable` Thread safety is managed by
/// the `ConnectionPool`
class Connection: @unchecked Sendable {
    let raw: OpaquePointer
    
    init(
        path: String,
        flags: Int32 = SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_NOMUTEX
            | SQLITE_OPEN_URI
    ) throws(FeatherError) {
        var raw: OpaquePointer?
        try throwing(sqlite3_open_v2(path, &raw, flags, nil))
        
        guard let raw else {
            throw .failedToOpenConnection(path: path)
        }
        
        self.raw = raw
    }
    
    func execute(sql: String) throws(FeatherError) {
        try throwing(sqlite3_exec(raw, sql, nil, nil, nil))
    }
    
    deinit {
        do {
            try throwing(sqlite3_close_v2(raw))
        } catch {
            assertionFailure("\(error)")
        }
    }
}
