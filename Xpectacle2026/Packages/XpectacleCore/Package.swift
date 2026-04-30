// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XpectacleCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "XpectacleCore", targets: ["XpectacleCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
    ],
    targets: [
        .target(
            name: "XpectacleCore",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "XpectacleCoreTests",
            dependencies: ["XpectacleCore"]
        ),
    ]
)
