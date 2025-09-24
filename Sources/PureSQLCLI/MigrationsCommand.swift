//
//  MigrationsCommand.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Compiler
import Foundation

struct MigrationsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrations",
        subcommands: [Add.self]
    )
    
    struct Add: ParsableCommand {
        @Option(name: .shortAndLong, help: "The directory containing the puresql.yaml")
        var path: String = FileManager.default.currentDirectoryPath
        
        static let configuration = CommandConfiguration(commandName: "add")
        
        func run() throws {
            let config = try Config(at: path)
            let project = config.project(at: path)
            try project.addMigration()
        }
    }
}
