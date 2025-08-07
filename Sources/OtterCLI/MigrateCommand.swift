//
//  MigrateCommand.swift
//  Otter
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Compiler
import Foundation

struct MigrateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        subcommands: [Add.self]
    )
    
    struct Add: ParsableCommand {
        @Option(name: .shortAndLong, help: "The directory containing the otter.yaml")
        var path: String = FileManager.default.currentDirectoryPath
        
        static let configuration = CommandConfiguration(commandName: "add")
        
        func run() throws {
            let config = try Config.load(at: path)
            let project = config.project(at: path)
            
            guard project.doesMigrationsExist else {
                throw OtterError.sourcesNotFound
            }
            
            try project.addMigration()
        }
    }
}
