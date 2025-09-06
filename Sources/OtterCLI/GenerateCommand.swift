//
//  GenerateCommand.swift
//  Otter
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Compiler
import Foundation
import SwiftSyntax

struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "generate")
    
    @Option(name: .shortAndLong, help: "The directory containing the otter.yaml")
    var path: String = FileManager.default.currentDirectoryPath
    
    @Option(name: .long, help: "If set, the output file overriden to it")
    var overrideOutput: String?
    
    @Flag(help: "If set, any diagnostic message will not be colorized")
    var dontColorize = false
    
    @Flag(help: "If set, core parts of the compilation will be timed")
    var time = false
    
    @Flag(help: "If true, the directory the output exists in will not be created if it doesn't exist")
    var skipDirectoryCreate = false
    
    @Flag(help: "If true, it will emit diagnostics that Xcode can understand")
    var xcodeDiagnosticReporter = false
    
    @Flag(help: "If true, the output will be dumped to stdout and not not be written to disk")
    var dump = false

    mutating func run() async throws {
        let config = try Config(at: path)
        var project = config.project(at: path)
        
        if let overrideOutput, let url = URL(string: overrideOutput) {
            project.generatedOutputFile = url
        }
        
        let options = GenerationOptions(
            databaseName: config.databaseName ?? "DB",
            imports: config.additionalImports ?? [],
            createDirectoryIfNeeded: !skipDirectoryCreate
        )
        
        try await generate(
            language: SwiftLanguage.self,
            options: options,
            project: project
        )
    }
    
    private func generate<Lang: Language>(
        language: Lang.Type,
        options: GenerationOptions,
        project: Project
    ) async throws {
        let driver = Driver()
        await driver.logTimes(time)
        
        if xcodeDiagnosticReporter {
            await driver.add(reporter: XcodeDiagnosticReporter())
        } else {
            await driver.add(reporter: StdoutDiagnosticReporter(dontColorize: dontColorize))
        }
        
        try await driver.compile(
            migrationsPath: project.migrationsDirectory.path,
            queriesPath: project.queriesDirectory.path
        )
        
        try await driver.generate(
            language: Lang.self,
            to: dump ? nil : project.generatedOutputFile.path,
            options: options
        )
        
        print("Generated output to \(project.generatedOutputFile.path)")
    }
}
