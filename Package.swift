// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Adderail",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "adderail", targets: ["AdderailCLI"]),
        .executable(name: "adderail-controller", targets: ["AdderailController"]),
        .library(name: "AdderailShared", targets: ["AdderailShared"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.7.1")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMinor(from: "1.5.2")),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", .upToNextMinor(from: "2.6.1"))
    ],
    targets: [
        .target(name: "AdderailShared"),
        .executableTarget(
            name: "AdderailCLI",
            dependencies: [
                "AdderailShared",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "AdderailController",
            dependencies: [
                "AdderailShared",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "AdderailControllerTests",
            dependencies: ["AdderailController"]
        ),
        .testTarget(
            name: "AdderailCLITests",
            dependencies: ["AdderailCLI"]
        )
    ]
)
