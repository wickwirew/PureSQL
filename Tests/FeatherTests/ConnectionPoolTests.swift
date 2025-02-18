//
//  ConnectionPoolTests.swift
//  Feather
//
//  Created by Wes Wickwire on 11/9/24.
//

import Testing
@testable import Feather

@Test func canOpenConnectionToPoolInMemory() async throws {
    _ = try ConnectionPool(name: ":memory:", migrations: [])
}
