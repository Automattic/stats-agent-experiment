// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "StatsAgent",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(name: "StatsAgent", targets: ["StatsAgent"]),
        .executable(name: "stats-agent", targets: ["stats-agent"]),
        .executable(name: "stats-agent-app", targets: ["StatsAgentApp"])
    ],
    dependencies: [
        // The revision the WordPress iOS app pins, for the stats views copied from it.
        .package(
            url: "https://github.com/Automattic/color-studio",
            revision: "bf141adc75e2769eb469a3e095bdc93dc30be8de"
        ),
        // The version the WordPress iOS app pins.
        .package(url: "https://github.com/automattic/wordpress-rs", exact: "0.9.1"),
        .package(url: "https://github.com/groue/GRDB.swift", exact: "7.11.1")
    ],
    targets: [
        .target(name: "StatsAgent"),
        .target(
            name: "StatsAgentDatabase",
            dependencies: ["StatsAgent", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(name: "stats-agent", dependencies: ["StatsAgent"]),
        .executableTarget(
            name: "StatsAgentApp",
            dependencies: [
                "StatsAgent",
                .product(name: "ColorStudio", package: "color-studio"),
                .product(name: "WordPressAPI", package: "wordpress-rs")
            ],
            // The bundle's `Info.plist`, which `make app` copies.
            exclude: ["Info.plist"],
            plugins: ["CredentialsPlugin"]
        ),
        .executableTarget(name: "generate-credentials"),
        .plugin(name: "CredentialsPlugin", capability: .buildTool(), dependencies: ["generate-credentials"]),
        .testTarget(
            name: "StatsAgentTests",
            dependencies: ["StatsAgent", "StatsAgentDatabase", .product(name: "GRDB", package: "GRDB.swift")]
        )
    ]
)
