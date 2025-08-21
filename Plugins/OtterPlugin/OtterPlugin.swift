//
//  OtterPlugin.swift
//  Otter
//
//  Created by Wes Wickwire on 8/11/25.
//

import PackagePlugin
import Foundation

@main
struct OtterPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        return [
            createBuildCommand(
                projectRoot: context.package.directoryURL,
                cliToolURL: try context.tool(named: "OtterCLI").url,
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
            displayName: "Running otter generate",
            executable: cliToolURL,
            arguments: [
                "generate",
                "--path",
                projectRoot.absoluteString,
                "--override-output",
                queries.absoluteString,
                "--skip-directory-create"
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

extension OtterPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        return [
            createBuildCommand(
                projectRoot: context.xcodeProject.directoryURL,
                cliToolURL: try context.tool(named: "OtterCLI").url,
                sourceFiles: target.inputFiles,
                workDirectory: context.pluginWorkDirectoryURL
            )
        ]
    }
}
#endif
