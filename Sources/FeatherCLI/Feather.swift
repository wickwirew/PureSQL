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
}

@main
struct Feather: ParsableCommand {
    @Option(name: .shortAndLong, help: "The root directory of the Feather sources")
    var path: String? = nil
    
    @Option(name: .shortAndLong, help: "Where the output files should be written to. Default is stdout")
    var output: String? = nil

    mutating func run() throws {
        let path = path ?? FileManager.default.currentDirectoryPath
        let migrations = "\(path)/Migrations"
        let queries = "\(path)/Queries"
        
        var schema = Schema()

        try forEachFile(in: migrations) { file, _ in
            var compiler = Compiler(schema: schema)
            compiler.compile(file)
            schema = compiler.schema
        }
        
        let outputFiles = try forEachFile(in: queries) { file, fileName in
            var compiler = Compiler(schema: schema)
            compiler.compile(file)
            
            var codeGen = CodeGen(schema: schema, statements: compiler.statements, source: file)
            return try (codeGen.gen().formatted(), fileName)
        }
        
        if let output {
            // Create the directory if it does not exist
            if !FileManager.default.fileExists(atPath: output) {
                try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
            }
            
            for (file, fileName) in outputFiles {
                let swiftFileName = "\(fileName.split(separator: ".")[0]).swift"
                try file.description.write(toFile: "\(output)/\(swiftFileName)", atomically: true, encoding: .utf8)
            }
        } else {
            // No output directory, just print to stdout
            for (file, _) in outputFiles {
                print(file)
            }
        }
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
}
