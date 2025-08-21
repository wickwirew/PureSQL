//
//  OtterPlugin.swift
//  Otter
//
//  Created by Wes Wickwire on 8/11/25.
//

import PackagePlugin

@main
struct OtterPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        guard target is SourceModuleTarget else { return [] }
        
        let sourceRoot = context.package.directoryURL.absoluteString
        
        let queries = context.pluginWorkDirectoryURL
            .appending(component: "Queries.swift")
        
        let inputFiles = target.sourceModule?.sourceFiles
            .filter { $0.url.pathExtension == "sql" }
            .map(\.url)
        
        return [
            .buildCommand(
                displayName: "Running otter generate",
                executable: try context.tool(named: "OtterCLI").url,
                arguments: [
                    "generate",
                    "--path",
                    sourceRoot,
                    "--override-output",
                    queries.absoluteString,
                    "--skip-directory-create"
                ],
                inputFiles: inputFiles ?? [],
                outputFiles: [queries]
            )
        ]
    }
}
