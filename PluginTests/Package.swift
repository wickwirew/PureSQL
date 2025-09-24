// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PluginTests",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(path: "../"),
    ],
    targets: [
        .executableTarget(
            name: "PluginTests",
            dependencies: ["PureSQL"],
            plugins: [.plugin(name: "PureSQLPlugin", package: "PureSQL")]
        ),
    ]
)
