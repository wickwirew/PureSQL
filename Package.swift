// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Feather",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Feather",
            targets: ["Feather"]
        ),
        .executable(
            name: "FeatherClient",
            targets: ["FeatherClient"]
        ),
        .executable(
            name: "feather",
            targets: ["FeatherCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "FeatherMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "Compiler",
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "Feather", dependencies: ["FeatherMacros", .product(name: "Collections", package: "swift-collections")]),
        .target(
            name: "Compiler",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "FeatherClient", dependencies: ["Feather"], resources: [.copy("example.db")]),
        
        .executableTarget(
            name: "FeatherCLI",
            dependencies: [
                "Compiler",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        // A test target used to develop the macro implementation.
        .testTarget(
            name: "FeatherTests",
            dependencies: [
                "Feather",
            ]
        ),

        .testTarget(
            name: "CompilerTests",
            dependencies: ["Compiler"],
            resources: [.process("SQL"), .process("Parser")]
        ),
    ]
)
