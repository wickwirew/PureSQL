//
//  TestTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/16/25.
//

import Testing
@testable import Feather

@Suite
struct TestTests {
    struct ExpectedError: Equatable, Error {}
    
    @Test func executeCallCountIsTracked() async throws {
        let query = Queries.Test<(), ()>()
        try await query.execute()
        #expect(query.executeCallCount == 1)
        try await query.execute()
        #expect(query.executeCallCount == 2)
    }
    
    @Test func observeCallCountIsTracked() async throws {
        let query = Queries.Test<(), ()>()
        for try await _ in query.observe() {}
        #expect(query.observeCallCount == 1)
        #expect(query.startObservationCallCount == 1)
        #expect(query.cancelObservationCallCount == 1)
        for try await _ in query.observe() {}
        #expect(query.observeCallCount == 2)
        #expect(query.startObservationCallCount == 2)
        #expect(query.cancelObservationCallCount == 2)
    }
    
    @Test func observeOutputsOnceThenFinishes() async throws {
        let query = Queries.Test<(), ()>()
        var count = 0
        for try await _ in query.observe() {
            count += 1
        }
        #expect(count == 1)
    }
    
    @Test func initialierThatTakesAnErrorThrows() async throws {
        let query = Queries.Test<(), ()>(error: ExpectedError())
        
        await #expect(throws: ExpectedError.self) {
            try await query.execute()
        }
    }
}
