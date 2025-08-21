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
            dependencies: ["Otter"],
            plugins: [.plugin(name: "OtterPlugin", package: "Otter")]
        ),
    ]
)
