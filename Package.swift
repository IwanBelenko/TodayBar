// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TodayBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TodayBar", targets: ["TodayBar"])
    ],
    targets: [
        .executableTarget(
            name: "TodayBar",
            path: "AppSources/TodayBar"
        )
    ]
)
