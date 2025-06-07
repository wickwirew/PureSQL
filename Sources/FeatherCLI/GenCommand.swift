//
//  GenCommand.swift
//  Feather
//
//  Created by Wes Wickwire on 5/21/25.
//

import Foundation
import ArgumentParser
import Compiler
import SwiftSyntax

struct GenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "gen")
    
    @Option(name: .shortAndLong, help: "The root directory of the Feather sources")
    var path: String = FileManager.default.currentDirectoryPath
    
    @Option(name: .shortAndLong, help: "The output file path. Default is to stdout")
    var output: String? = nil
    
    @Option(name: .shortAndLong, help: "The database name")
    var databaseName: String = "DB"
    
    @Option(name: .shortAndLong, help: "Comma separated list of additional imports to add")
    var additionalImports: String?
    
    @Flag(help: "If set, any diagnostic message will not be colorized")
    var dontColorize = false
    
    @Flag(help: "If set, core parts of the compilation will be timed")
    var time = false

    mutating func run() async throws {
        let options = GenerationOptions(
            databaseName: databaseName,
            imports: additionalImports?.split(separator: ",").map(\.description) ?? []
        )
        
        try await generate(language: SwiftLanguage.self, options: options)
    }
    
    private func generate<Lang: Language>(
        language: Lang.Type,
        options: GenerationOptions
    ) async throws {
        let driver = Driver()
        await driver.logTimes(time)
        
        await driver.add(
            reporter: StdoutDiagnosticReporter(dontColorize: dontColorize)
        )
        
        try await driver.compile(path: path)
        
        try await driver.generate(
            language: Lang.self,
            to: output,
            options: options
        )
    }
}
