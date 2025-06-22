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
        static let configuration = CommandConfiguration(commandName: "add")
        
        @Argument var name: String
        
        func run() throws {
            let project = Project.inWorkingDir()
            
            guard project.doesQueriesExist else {
                throw OtterError.sourcesNotFound
            }
            
            guard !project.doesQueryExist(withName: name) else {
                throw OtterError.queryAlreadyExists(fileName: name)
            }
            
            try project.addQuery(named: name)
        }
    }
}
