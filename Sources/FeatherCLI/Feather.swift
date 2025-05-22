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

@main
struct Feather: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        subcommands: [GenCommand.self, InitCommand.self, MigrateCommand.self, QueriesCommand.self],
        defaultSubcommand: GenCommand.self
    )
}

enum FeatherError: Error, CustomStringConvertible {
    case sourcesNotFound
    case queryAlreadyExists(fileName: String)
    
    var description: String {
        switch self {
        case .sourcesNotFound:
            "Sources not found, run init to initialize new project"
        case .queryAlreadyExists(let fileName):
            "Query file with name '\(fileName)' already exists"
        }
    }
}
