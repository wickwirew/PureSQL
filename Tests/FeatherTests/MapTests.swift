//
//  MapTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/16/25.
//

import Testing
@testable import Feather

@Suite
struct MapTests {
    struct ExpectedError: Equatable, Error {}
    
    @Test func mapTransformsOutput() async throws {
        let query = Queries.Just<(), Int>(100)
        let output = try await query.map { $0.description }.execute()
        #expect(output == "100")
    }
    
    @Test func mapTransformsOutput_Observation() async throws {
        let query = Queries.Just<(), Int>(100).map(\.description)
        
        var count = 0
        for try await output in query.observe() {
            count += 1
            #expect(output == "100")
        }
        #expect(count == 1)
    }
    
    @Test func mapErrorsArePropagatedUp() async throws {
        let query = Queries.Just<(), Int>(100)
        
        await #expect(throws: ExpectedError.self) {
            try await query.map { _ in throw ExpectedError() }.execute()
        }
    }
    
    @Test func throwIfNotFoundReturnsDefaultError() async throws {
        let query = Queries.Just<(), Int?>(nil)
        
        await #expect(throws: FeatherError.self) {
            try await query.throwIfNotFound().execute()
        }
    }
    
    @Test func throwIfNotFoundThrowsInputErrorIfNil() async throws {
        let query = Queries.Just<(), Int?>(nil)
        
        await #expect(throws: ExpectedError.self) {
            try await query.throwIfNotFound{ _ in ExpectedError() }.execute()
        }
    }
    
    @Test func throwIfNotFoundThrowsInputErrorIfNil_AutoClosure() async throws {
        let query = Queries.Just<(), Int?>(nil)
        
        await #expect(throws: ExpectedError.self) {
            try await query.throwIfNotFound(ExpectedError()).execute()
        }
    }
    
    @Test func replaceNilReplacesNilOutput() async throws {
        let query = Queries.Just<(), Int?>(nil)
        let output = try await query.replaceNil(with: 100).execute()
        #expect(output == 100)
    }
    
    @Test func replaceNilDoesNotReplaceNonNilValue() async throws {
        let query = Queries.Just<(), Int?>(100)
        let output = try await query.replaceNil(with: 123).execute()
        #expect(output == 100)
    }
}
