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
        static let configuration = CommandConfiguration(commandName: "add")
        
        func run() throws {
            let project = Project.inWorkingDir()
            
            guard project.doesMigrationsExist else {
                throw OtterError.sourcesNotFound
            }
            
            try project.addMigration()
        }
    }
}
