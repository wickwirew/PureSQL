//
//  MigrateCommand.swift
//  Feather
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Foundation
import Compiler

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
                throw FeatherError.sourcesNotFound
            }
            
            try project.addMigration()
        }
    }
}
