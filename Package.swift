// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Otter",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13)
    ],
    products: [
        .library(name: "Otter", targets: ["Otter"]),
        .library(name: "Compiler", targets: ["Compiler"]),
        .executable(name: "OtterCLI", targets: ["OtterCLI"]),
        .plugin(name: "OtterPlugin", targets: ["OtterPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0-latest"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.0.2"),
    ],
    targets: [
        .macro(
            name: "OtterMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "Compiler",
            ]
        ),

        .target(
            name: "Otter",
            dependencies: [
                "OtterMacros",
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
            name: "OtterCLI",
            dependencies: [
                "Compiler",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        .plugin(
            name: "OtterPlugin",
            capability: .buildTool(),
            dependencies: ["OtterCLI"]
        ),

        .testTarget(
            name: "OtterTests",
            dependencies: ["Otter", "Compiler"]
        ),

        .testTarget(
            name: "CompilerTests",
            dependencies: ["Compiler"],
            resources: [.process("Compiler"), .process("Parser"), .process("Gen")]
        ),
    ]
)
