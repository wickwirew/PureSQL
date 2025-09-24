//
//  FailTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/16/25.
//

@testable import PureSQL
import Testing

@Suite
struct FailTests {
    struct ExpectedError: Equatable, Error {}
    
    @Test func executeThrowsInputError() async {
        let query = Queries.Fail<Void, Void>(ExpectedError())
        
        await #expect(throws: ExpectedError.self) {
            try await query.execute()
        }
    }
    
    @Test func observeThrowsInputError() async {
        let query = Queries.Fail<Void, Void>(ExpectedError())
        
        await #expect(throws: ExpectedError.self) {
            for try await _ in query.observe() {}
        }
    }
}
