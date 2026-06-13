//
//  DriverTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/13/26.
//

import Testing
import Foundation

@testable import Compiler

@Suite
struct DriverTests {
    @Test func migrationsAreGeneratedInNumericOrder() async throws {
        let numbers = [0, 11, 2, 10, 1, 9, 3, 8, 4, 7, 5, 6]

        var files: [String: String] = [:]
        for n in numbers {
            files["migrations/\(n).sql"] = "CREATE TABLE m\(n)_marker (id INTEGER);"
        }

        let fileSystem = FileSystemMock(
            directories: ["migrations": numbers.map { "\($0).sql" }],
            files: files
        )

        let driver = Driver(fileSystem: fileSystem)
        try await driver.compile(migrationsPath: "migrations", queriesPath: "queries")
        try await driver.generate(
            language: SwiftLanguage.self,
            to: "out/DB.swift",
            options: GenerationOptions(databaseName: "DB")
        )

        let output = try #require(fileSystem.writtenContents(at: "out/DB.swift"))

        var lastLocation = output.startIndex
        for n in 0...11 {
            let marker = "m\(n)_marker"
            let range = try #require(
                output.range(of: marker),
                "Generated output is missing migration marker \(marker)"
            )
            #expect(
                range.lowerBound > lastLocation || n == 0,
                "Migration \(n) is out of order in the generated output"
            )
            lastLocation = range.lowerBound
        }
    }
}
