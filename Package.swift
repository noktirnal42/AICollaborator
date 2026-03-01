// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AICollaborator",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AICollaborator",
            targets: ["AICollaboratorApp"]
        ),
        .executable(
            name: "AICollaboratorCLI",
            targets: ["AICollaboratorCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "AICollaboratorApp",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "Sources/AICollaboratorApp"
        ),
        .executableTarget(
            name: "AICollaboratorCLI",
            dependencies: [
                "AICollaboratorApp",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/AICollaboratorCLI"
        ),
        .testTarget(
            name: "AICollaboratorTests",
            dependencies: ["AICollaboratorApp"],
            path: "Tests/AICollaboratorTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
