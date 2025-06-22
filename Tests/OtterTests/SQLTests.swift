//
//  SQLTests.swift
//  Otter
//
//  Created by Wes Wickwire on 2/19/25.
//

@testable import Otter
import Testing

@Suite
struct SQLTests {
    @Test func testNoParams() async throws {
        let sql: SQL = "SELECT * FROM foo"
        #expect(sql.source == "SELECT * FROM foo")
        #expect(sql.parameters.isEmpty)
    }

    @Test func singleParameter() async throws {
        let sql: SQL = "SELECT * FROM foo WHERE id = \(1)"
        #expect(sql.source == "SELECT * FROM foo WHERE id = ?")
        #expect(sql.parameters.count == 1)
    }

    @Test func arrayOfParameters() async throws {
        let sql: SQL = "SELECT * FROM foo WHERE id IN \([1, 2, 3])"
        #expect(sql.source == "SELECT * FROM foo WHERE id IN (?,?,?)")
        #expect(sql.parameters.count == 3)
    }

    @Test func stringIsAddedAsParameter() async throws {
        let sql: SQL = "SELECT * FROM foo WHERE id = \("value")"
        #expect(sql.source == "SELECT * FROM foo WHERE id = ?")
        #expect(sql.parameters.count == 1)
    }
}
