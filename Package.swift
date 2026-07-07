// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LidFlow",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "LidFlow",
            path: "Sources/LidFlow",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
