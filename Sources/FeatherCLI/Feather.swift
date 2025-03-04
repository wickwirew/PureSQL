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

    mutating func run() throws {
        try generate(language: SwiftGenerator.self)
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

        var migrations: [Lang.Migration] = []
        var queries: [Lang.Query] = []
        
        try forEachFile(in: "\(path)/Migrations") { file, fileName in
            let diags = compiler.compile(migration: file)
            
            let numberStr = fileName.split(separator: ".")[0]
            guard Int(numberStr) != nil else {
                throw CLIError.migrationFileNameMustBeNumber(fileName)
            }
            
            report(diagnostics: diags, forFile: fileName)
        }
        
        try migrations.append(contentsOf: compiler.migrations.map { try language.migration(source: $0.sanitizedSource) })
        
        try forEachFile(in: "\(path)/Queries") { file, fileName in
            let diags = compiler.compile(queries: file)
            report(diagnostics: diags, forFile: fileName)
        }
        
        for statement in compiler.queries {
            guard let name = statement.name else {
                // Should have been caught up stream
                assertionFailure("Statement in queries has no name")
                continue
            }
            try queries.append(language.query(statement: statement, name: name))
        }
        
        let tables = try compiler.schema
            .map { try language.table(name: $0.key, columns: $0.value.columns) }
        
        let file = try language.file(
            migrations: migrations,
            tables: tables,
            queries: queries
        )
        
        if let output {
            try validateIsFile(output)
            try createDirectoiesIfNeeded(output)
            
            try language.string(for: file)
                .write(toFile: output, atomically: true, encoding: .utf8)
        } else {
            // No output directory, just print to stdout
            print(language.string(for: file))
        }
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
    
    private func report(diagnostics: Diagnostics, forFile fileName: String) {
        for diag in diagnostics {
            print(diag)
        }
    }
}
