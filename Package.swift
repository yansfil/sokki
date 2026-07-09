// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sokki",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sokki", targets: ["Sokki"]),
        .executable(name: "SokkiCoreTestRunner", targets: ["SokkiCoreTestRunner"]),
        .library(name: "SokkiCore", targets: ["SokkiCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "SokkiCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "Sokki",
            dependencies: [
                "SokkiCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
        .executableTarget(
            name: "SokkiCoreTestRunner",
            dependencies: ["SokkiCore"]
        )
    ]
)
