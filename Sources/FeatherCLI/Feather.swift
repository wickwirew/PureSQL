//
//  Feather.swift
//  FeatherCLI
//
//  Created by Wes Wickwire on 1/18/24.
//

import Foundation
import ArgumentParser
import Compiler
import SwiftSyntax

@main
struct Feather: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "The root directory of the Feather sources")
    var path: String = FileManager.default.currentDirectoryPath
    
    @Option(name: .shortAndLong, help: "The output file path. Default is to stdout")
    var output: String? = nil
    
    @Option(name: .shortAndLong, help: "The database name")
    var databaseName: String = "DB"
    
    @Option(name: .shortAndLong, help: "Comma separated list of additional imports to add")
    var additionalImports: String?
    
    mutating func run() async throws {
        try await generate(language: SwiftLanguage.self)
    }
    
    private func generate<Lang: Language>(language: Lang.Type) async throws {
        let driver = Driver()
        await driver.add(reporter: StdoutDiagnosticReporter())
        
        try await driver.compile(path: path)
        
        try await driver.generate(
            language: Lang.self,
            to: output,
            imports: additionalImports?.split(separator: ",").map(\.description) ?? [],
            databaseName: databaseName,
            options: gatherOptions()
        )
    }
    
    private func gatherOptions() -> GenerationOptions {
        return [] // This originally had options
    }
}
