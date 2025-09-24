//
//  PureSQL.swift
//  PureSQLCLI
//
//  Created by Wes Wickwire on 1/18/24.
//

import ArgumentParser
import Compiler
import Foundation
import SwiftSyntax

@main
struct PureSQL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "puresql",
        subcommands: [
            GenerateCommand.self,
            InitCommand.self,
            MigrationsCommand.self,
            QueriesCommand.self
        ],
        defaultSubcommand: GenerateCommand.self
    )
}

enum PureSQLError: Error, CustomStringConvertible {
    case sourcesNotFound
    case queryAlreadyExists(fileName: String)
    case configDoesNotExist

    var description: String {
        switch self {
        case .sourcesNotFound:
            "Sources not found, run init to initialize new project"
        case let .queryAlreadyExists(fileName):
            "Query file with name '\(fileName)' already exists"
        case .configDoesNotExist:
            "puresql.yaml not found"
        }
    }
}
