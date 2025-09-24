//
//  PureSQLPlugin.swift
//  PureSQL
//
//  Created by Wes Wickwire on 8/11/25.
//

import PackagePlugin
import Foundation

@main
struct PureSQLPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        return [
            createBuildCommand(
                projectRoot: context.package.directoryURL,
                cliToolURL: try context.tool(named: "PureSQLCLI").url,
                sourceFiles: target.sourceModule?.sourceFiles,
                workDirectory: context.pluginWorkDirectoryURL
            )
        ]
    }
    
    private func createBuildCommand(
        projectRoot: URL,
        cliToolURL: URL,
        sourceFiles: FileList?,
        workDirectory: URL
    ) -> Command {
        let queries = workDirectory.appending(component: "Queries.swift")
        
        return .buildCommand(
            displayName: "Running puresql generate",
            executable: cliToolURL,
            arguments: [
                "generate",
                "--path",
                projectRoot.absoluteString,
                "--override-output",
                queries.absoluteString,
                "--skip-directory-create",
                "--xcode-diagnostic-reporter"
            ],
            inputFiles: sourceFiles?
                .filter { $0.url.pathExtension == "sql" }
                .map(\.url) ?? [],
            outputFiles: [queries]
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension PureSQLPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        return [
            createBuildCommand(
                projectRoot: context.xcodeProject.directoryURL,
                cliToolURL: try context.tool(named: "PureSQLCLI").url,
                sourceFiles: target.inputFiles,
                workDirectory: context.pluginWorkDirectoryURL
            )
        ]
    }
}
#endif
