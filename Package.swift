// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "PureSQL",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
    ],
    products: [
        .library(name: "PureSQL", targets: ["PureSQL"]),
        .library(name: "Compiler", targets: ["Compiler"]),
        .executable(name: "PureSQLCLI", targets: ["PureSQLCLI"]),
        .plugin(name: "PureSQLPlugin", targets: ["PureSQLPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0-latest"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.0.2"),
    ],
    targets: [
        .macro(
            name: "PureSQLMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "Compiler",
            ]
        ),

        .target(
            name: "PureSQL",
            dependencies: [
                "PureSQLMacros",
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),

        .target(
            name: "Compiler",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                "Yams",
            ]
        ),

        .executableTarget(
            name: "PureSQLCLI",
            dependencies: [
                "Compiler",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        .plugin(
            name: "PureSQLPlugin",
            capability: .buildTool(),
            dependencies: ["PureSQLCLI"]
        ),

        .testTarget(
            name: "PureSQLTests",
            dependencies: ["PureSQL", "Compiler"]
        ),

        .testTarget(
            name: "CompilerTests",
            dependencies: ["Compiler"],
            resources: [.process("Compiler"), .process("Parser"), .process("Gen")]
        ),
    ]
)
