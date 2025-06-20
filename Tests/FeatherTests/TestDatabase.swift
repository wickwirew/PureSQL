//
//  TestDatabase.swift
//  Feather
//
//  Created by Wes Wickwire on 6/14/25.
//

import Feather
import Foundation

/// A database to use for unit tests
@Database
struct TestDB {
    @Query("SELECT * FROM foo")
    var selectFoos: SelectFoosDatabaseQuery
    
    @Query("SELECT * FROM foo WHERE bar = ?")
    var selectFoo: SelectFooDatabaseQuery

    @Query("INSERT INTO foo (bar) VALUES (?)")
    var insertFoo: InsertFooDatabaseQuery
    
    static var migrations: [String] {
        return [
            "CREATE TABLE foo (bar INTEGER PRIMARY KEY);"
        ]
    }
}

extension TestDB {
    /// Creates a database on disk in the temp directory.
    /// Will delete the DB if it already exists
    static func inTempDir(
        name: StaticString = #function,
        maxConnectionCount: Int = 5
    ) throws -> TestDB {
        let temp = FileManager.default.temporaryDirectory
            .appending(component: "\(name).db")
        
        if FileManager.default.fileExists(atPath: temp.path) {
            try FileManager.default.removeItem(atPath: temp.path)
        }
        
        let config = DatabaseConfig(path: temp.path, maxConnectionCount: maxConnectionCount)
        return try TestDB(config: config)
    }
}
