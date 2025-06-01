//
//  DatabaseMacroTests.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

import Testing
import Feather

//@Suite
//struct DatabaseMacroTests {
//    @Test func insertAndSelect() async throws {
//        let database = try TestDB.inMemory()
//        
//        try await database.insertFoo.execute(with: .init(bar: 1, baz: "Meow", qux: 1))
//        
//        let foos = try await database.selectFoo.execute()
//        
//        for foo in foos {
//            print(foo)
//        }
//    }
//    
//    @Database
//    struct TestDB {
//        @Query("SELECT * FROM foo")
//        var selectFoo: SelectFooDatabaseQuery
//
//        @Query("INSERT INTO foo (bar, baz, qux) VALUES (?, ?, ?)", inputName: "Meow")
//        var insertFoo: InsertFooDatabaseQuery
//        
//        static var migrations: [String] {
//            return [
//                "CREATE TABLE foo (bar INTEGER, baz TEXT, qux ANY);"
//            ]
//        }
//    }
//}
