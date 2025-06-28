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
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", from: "601.0.1"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
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
            ]
        ),

        .executableTarget(
            name: "OtterCLI",
            dependencies: [
                "Compiler",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
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
