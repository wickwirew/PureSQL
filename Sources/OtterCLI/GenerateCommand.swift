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
    
    @Flag(help: "If set, any diagnostic message will not be colorized")
    var dontColorize = false
    
    @Flag(help: "If set, core parts of the compilation will be timed")
    var time = false

    mutating func run() async throws {
        let config = try Config.load(at: path)
        let project = config.project(at: path)
        
        let options = GenerationOptions(
            databaseName: config.databaseName ?? "DB",
            imports: config.additionalImports ?? []
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
        
        await driver.add(
            reporter: StdoutDiagnosticReporter(dontColorize: dontColorize)
        )
        
        try await driver.compile(
            migrationsPath: project.migrationsDirectory.path,
            queriesPath: project.queriesDirectory.path
        )
        
        try await driver.generate(
            language: Lang.self,
            to: project.generatedOutputFile.path,
            options: options
        )
        
        print("Generated output to \(project.generatedOutputFile.path)")
    }
}
