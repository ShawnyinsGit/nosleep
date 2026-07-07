// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NoSleep",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NoSleep",
            path: "Sources/NoSleep",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
