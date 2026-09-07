// swift-tools-version: 5.10
import PackageDescription

// target 名必须与 AppIdentity.name 一致。
let package = Package(
    name: "AICreditBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AICreditBar",
            path: "Sources/AICreditBar",
            resources: [
                .copy("Resources/ProviderLogos"),
                .copy("Resources/Locales")
            ]
        )
    ]
)
