//
//  QueriesCommand.swift
//  Otter
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Compiler
import Foundation

struct QueriesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queries",
        subcommands: [Add.self]
    )
    
    struct Add: ParsableCommand {
        @Option(name: .shortAndLong, help: "The directory containing the otter.yaml")
        var path: String = FileManager.default.currentDirectoryPath
        
        @Argument var name: String
        
        static let configuration = CommandConfiguration(commandName: "add")
        
        func run() throws {
            let config = try Config(at: path)
            let project = config.project(at: path)
            
            guard !project.doesQueryExist(withName: name) else {
                throw OtterError.queryAlreadyExists(fileName: name)
            }
            
            try project.addQuery(named: name)
        }
    }
}
