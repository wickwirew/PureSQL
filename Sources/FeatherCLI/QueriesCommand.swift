//
//  QueriesCommand.swift
//  Feather
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Foundation
import Compiler

struct QueriesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queries",
        subcommands: [Add.self]
    )
    
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "add")
        
        @Argument var name: String
        
        func run() throws {
            let project = Project(url: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            
            guard project.doesQueriesExist else {
                throw FeatherError.sourcesNotFound
            }
            
            guard !project.doesQueryExist(withName: name) else {
                throw FeatherError.queryAlreadyExists(fileName: name)
            }
            
            try project.addQuery(named: name)
        }
    }
}
