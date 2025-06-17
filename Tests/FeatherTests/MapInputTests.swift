//
//  MapInputTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/16/25.
//

import Testing
@testable import Feather

@Suite
struct MapInputTests {
    @Test func mapInputMapsInput() async throws {
        let query = Queries.Just<String, Int>(100)
        let newInput: any Query<Int, Int> = query.mapInput(to: Int.self) { $0.description }
        let output = try await newInput.execute(with: 1)
        #expect(output == 100)
    }
}

