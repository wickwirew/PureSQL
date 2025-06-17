//
//  JustTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/16/25.
//

import Testing
@testable import Feather

@Suite
struct JustTests {
    @Test func executeReturnsDefinedOutput() async throws {
        let output = try await Queries.Just<Int, String>("foo").execute(with: 1)
        #expect(output == "foo")
    }
    
    @Test func observeReturnsOutputOnceAndFinishes() async throws {
        let query = Queries.Just<Int, String>("foo")
        var count = 0
        
        for try await value in query.observe(with: 1) {
            count += 1
            #expect(value == "foo")
        }
        
        #expect(count == 1)
    }
    
    @Test func arrayOutputDefaultInitIsEmpty() async throws {
        let query = Queries.Just<(), [String]>()
        let output = try await query.execute()
        #expect(output == [])
    }
    
    @Test func optionalOutputDefaultInitIsNil() async throws {
        let query = Queries.Just<(), String?>()
        let output = try await query.execute()
        #expect(output == nil)
    }
    
    @Test func voidOutputDefaultInitIsVoid() async throws {
        // Silly test but i dont want to delete it on accident
        let _ = Queries.Just<(), ()>()
    }
}
