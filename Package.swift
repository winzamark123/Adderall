// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Adderall",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "adderall", targets: ["AdderallCLI"]),
        .executable(name: "adderall-controller", targets: ["AdderallController"]),
        .library(name: "AdderallShared", targets: ["AdderallShared"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.7.1")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMinor(from: "1.5.2")),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", .upToNextMinor(from: "2.6.1"))
    ],
    targets: [
        .target(name: "AdderallShared"),
        .executableTarget(
            name: "AdderallCLI",
            dependencies: [
                "AdderallShared",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "AdderallController",
            dependencies: [
                "AdderallShared",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "AdderallControllerTests",
            dependencies: ["AdderallController"]
        ),
        .testTarget(
            name: "AdderallCLITests",
            dependencies: ["AdderallCLI"]
        )
    ]
)
