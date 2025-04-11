// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AICollaborator",
    platforms: [
        .macOS(.v13)
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
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        // Adding Python Integration using PythonKit instead of PythonSwiftCore
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.4.1")
    ],
    targets: [
        .target(
            name: "AICollaboratorApp",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "PythonKit", package: "PythonKit")
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
    swiftLanguageVersions: [.v5]
)
