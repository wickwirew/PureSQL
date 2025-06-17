//
//  FailTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/16/25.
//

import Testing
@testable import Feather

@Suite
struct FailTests {
    struct ExpectedError: Equatable, Error {}
    
    @Test func executeThrowsInputError() async {
        let query = Queries.Fail<(), ()>(ExpectedError())
        
        await #expect(throws: ExpectedError.self) {
            try await query.execute()
        }
    }
    
    @Test func observeThrowsInputError() async {
        let query = Queries.Fail<(), ()>(ExpectedError())
        
        await #expect(throws: ExpectedError.self) {
            for try await _ in query.observe() {}
        }
    }
}
