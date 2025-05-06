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

enum CLIError: Error {
    case fileIsNotValidUTF8(path: String)
    case migrationFileNameMustBeNumber(String)
    case invalidOutput(String)
    case outputMustBeFileNotDirectory(String)
}

@main
struct Feather: ParsableCommand {
    @Option(name: .shortAndLong, help: "The root directory of the Feather sources")
    var path: String? = nil
    
    @Option(name: .shortAndLong, help: "The output file path. Default is to stdout")
    var output: String? = nil
    
    @Option(name: .shortAndLong, help: "The database name")
    var databaseName: String = "DB"
    
    @Flag(name: .long, help: "Whether or not the generated models should be namespace under the DB struct")
    var namespaceModels: Bool = false

    mutating func run() throws {
        try generate(language: SwiftLanguage.self)
    }
    
    @discardableResult
    private func forEachFile<T>(
        in path: String,
        execute: (String, String) throws -> T
    ) throws -> [T] {
        var result: [T] = []
        
        for file in try FileManager.default.contentsOfDirectory(atPath: path).sorted() {
            let data = try Data(contentsOf: URL(fileURLWithPath: "\(path)/\(file)"))
            
            guard let source = String(data: data, encoding: .utf8) else {
                throw CLIError.fileIsNotValidUTF8(path: path)
            }
            
            try result.append(execute(source, file))
        }
        
        return result
    }
    
    private func generate<Lang: Language>(language: Lang.Type) throws {
        let path = path ?? FileManager.default.currentDirectoryPath
        var compiler = Compiler()

        try forEachFile(in: "\(path)/Migrations") { file, fileName in
            let diags = compiler.compile(migration: file, namespace: .file(fileName))
            
            let numberStr = fileName.split(separator: ".")[0]
            guard Int(numberStr) != nil else {
                throw CLIError.migrationFileNameMustBeNumber(fileName)
            }
            
            report(diagnostics: diags, source: file, forFile: fileName)
        }
        
        try forEachFile(in: "\(path)/Queries") { file, fileName in
            let diags = compiler.compile(queries: file, namespace: .file(fileName))
            report(diagnostics: diags, source: file, forFile: fileName)
        }
        
        let file = try Lang.generate(
            databaseName: databaseName,
            migrations: compiler.migrations.map(\.sanitizedSource),
            queries: compiler.queries,
            schema: compiler.schema,
            options: gatherOptions()
        )
        
        guard !compiler.hasDiagnostics else {
            return
        }
        
        if let output {
            try validateIsFile(output)
            try createDirectoiesIfNeeded(output)
            
            try file.write(toFile: output, atomically: true, encoding: .utf8)
        } else {
            // No output directory, just print to stdout
            print(file)
        }
    }
    
    private func gatherOptions() -> GenerationOptions {
        var options: GenerationOptions = []
        
        if namespaceModels {
            options.insert(.namespaceGeneratedModels)
        }
        
        return options
    }
    
    private func createDirectoiesIfNeeded(_ output: String) throws {
        let url = URL(fileURLWithPath: output)
        let directory = url.deletingLastPathComponent()
        
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        
        try FileManager.default.createDirectory(
            atPath: directory.path,
            withIntermediateDirectories: true
        )
    }
    
    private func validateIsFile(_ output: String) throws {
        if output.split(separator: ".").count <= 1 {
            throw CLIError.outputMustBeFileNotDirectory(output)
        }
    }
    
    private func report(
        diagnostics: Diagnostics,
        source: String,
        forFile fileName: String
    ) {
        let reporter = StdoutDiagnosticReporter()
        
        for diag in diagnostics.elements {
            reporter.report(diagnostic: diag, source: source, fileName: fileName)
        }
    }
}
