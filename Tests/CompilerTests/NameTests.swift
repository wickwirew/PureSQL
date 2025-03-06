//
//  NameTests.swift
//  Feather
//
//  Created by Wes Wickwire on 3/5/25.
//

import Testing
@testable import Compiler

@Test func testPluralize() async throws {
    #expect(Name.some("id").pluralize() == .some("ids"))
    #expect(Name.some("city").pluralize() == .some("cities"))
    #expect(Name.some("y").pluralize() == .some("y"))
    #expect(Name.some("money").pluralize() == .some("money"))
}
