// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Fanyi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FanyiBar", targets: ["FanyiBar"]),
        .executable(name: "FanyiCoreChecks", targets: ["FanyiCoreChecks"]),
        .library(name: "FanyiCore", targets: ["FanyiCore"])
    ],
    targets: [
        .target(
            name: "FanyiCore",
            path: "Sources/FanyiCore"
        ),
        .executableTarget(
            name: "FanyiBar",
            dependencies: ["FanyiCore"],
            path: "Sources/FanyiBar"
        ),
        .executableTarget(
            name: "FanyiCoreChecks",
            dependencies: ["FanyiCore"],
            path: "Tests/FanyiCoreChecks"
        )
    ]
)
