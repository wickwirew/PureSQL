//
//  InitCommand.swift
//  Otter
//
//  Created by Wes Wickwire on 5/21/25.
//

import ArgumentParser
import Compiler
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init")

    func run() throws {
        let defaultConfig = """
        # The type name of the generated struct for the database 
        databaseName: DB
        # Path to the directory containing the migrations
        migrations: ProjectName/Migrations
        # Path to the directory containing the queries
        queries: ProjectName/Queries
        # The path of the file to generate the Swift code into
        output: ProjectName/Queries.swift
        # Uncomment to add any custom imports that may be needed
        # additionalImports:
        #     - MyModule
        """
        
        try defaultConfig.write(
            toFile: FileManager.default.currentDirectoryPath.appending("/otter.yaml"),
            atomically: true,
            encoding: .utf8
        )
        
        print("Created otter.yaml configration")
    }
}
