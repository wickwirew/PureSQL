//
//  InitCommand.swift
//  Feather
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Foundation
import Compiler

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init")
    
    func run() throws {
        let project = Project.inWorkingDir()
        try project.setup()
        try project.addMigration()
    }
}
