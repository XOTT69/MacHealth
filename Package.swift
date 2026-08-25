// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacHealth",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacHealth",
            path: "MacHealth",
            exclude: ["Assets.xcassets", "MacHealth.entitlements"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
