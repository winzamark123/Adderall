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
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.7.1"))
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
            dependencies: ["AdderallShared"],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "AdderallSharedTests",
            dependencies: ["AdderallShared"]
        ),
        .testTarget(
            name: "AdderallCLITests",
            dependencies: ["AdderallCLI"]
        )
    ]
)
