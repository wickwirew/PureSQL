// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

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
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
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
        .target(name: "Feather", dependencies: ["FeatherMacros"]),
        .target(name: "Compiler", dependencies: [.product(name: "OrderedCollections", package: "swift-collections")]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "FeatherClient", dependencies: ["Feather"], resources: [.copy("example.db")]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "FeatherTests",
            dependencies: [
                "FeatherMacros",
                "Compiler",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        
        .testTarget(
            name: "CompilerTests",
            dependencies: ["Compiler"],
            resources: [.process("SQL")]
        ),
    ]
)
