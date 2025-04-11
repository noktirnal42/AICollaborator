// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AICollaborator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Main library product
        .library(
            name: "AICollaborator",
            targets: ["AICollaboratorApp"]),
        
        // Command-line tool for AI agent interaction
        .executable(
            name: "AICollaboratorCLI",
            targets: ["AICollaboratorCLI"])
    ],
    dependencies: [
        // Swift Argument Parser for CLI commands
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        
        // Networking and API interactions
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.0"),
        
        // JSON parsing and manipulation
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.1"),
        
        // Natural language processing utilities
        .package(url: "https://github.com/apple/swift-nlp", from: "0.5.0"),
        
        // Async/concurrent utilities
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        // Main application target
        .target(
            name: "AICollaboratorApp",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "NaturalLanguage", package: "swift-nlp")
            ],
            path: "Sources/AICollaboratorApp",
            resources: [
                .process("Resources")
            ]
        ),
        
        // CLI tool target
        .executableTarget(
            name: "AICollaboratorCLI",
            dependencies: [
                "AICollaboratorApp",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/AICollaboratorCLI"
        ),
        
        // Test target
        .testTarget(
            name: "AICollaboratorTests",
            dependencies: ["AICollaboratorApp"],
            path: "Tests/AICollaboratorTests",
            resources: [
                .process("Resources")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
