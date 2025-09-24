//
//  TestDatabase.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/14/25.
//

import Foundation
import PureSQL

/// A database to use for unit tests
@Database
struct TestDB {
    @Query("SELECT * FROM foo")
    var selectFoos: any SelectFoosQuery

    @Query("SELECT * FROM foo WHERE bar = ?")
    var selectFoo: any SelectFooQuery

    @Query("INSERT INTO foo (bar) VALUES (?)")
    var insertFoo: any InsertFooQuery
    
    @Query("INSERT INTO baz (qux) VALUES (?)")
    var insertBaz: any InsertBazQuery
    
    @Query("SELECT foo.*, baz.* FROM foo LEFT OUTER JOIN baz ON foo.bar = baz.qux")
    var selectFooAndBaz: any SelectFooAndBazQuery
    
    @Query("SELECT foo.*, baz.* FROM foo INNER JOIN baz ON foo.bar = baz.qux")
    var selectFooAndBazNotOptional: any SelectFooAndBazNotOptionalQuery

    static var migrations: [String] {
        return [
            "CREATE TABLE foo (bar INTEGER PRIMARY KEY);",
            "CREATE TABLE baz (qux INTEGER PRIMARY KEY);"
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
        return try TestDB(config: config, adapters: TestDB.Adapters())
    }
}
