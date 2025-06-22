//
//  Otter.swift
//  OtterCLI
//
//  Created by Wes Wickwire on 1/18/24.
//

import ArgumentParser
import Compiler
import Foundation
import SwiftSyntax

@main
struct Otter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        subcommands: [GenCommand.self, InitCommand.self, MigrateCommand.self, QueriesCommand.self],
        defaultSubcommand: GenCommand.self
    )
}

enum OtterError: Error, CustomStringConvertible {
    case sourcesNotFound
    case queryAlreadyExists(fileName: String)

    var description: String {
        switch self {
        case .sourcesNotFound:
            "Sources not found, run init to initialize new project"
        case let .queryAlreadyExists(fileName):
            "Query file with name '\(fileName)' already exists"
        }
    }
}
