// swift-tools-version: 6.0
// Swift Package Manager configuration for MeetingAssistant

import PackageDescription

let package = Package(
    name: "MeetingAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MeetingAssistant",
            targets: ["MeetingAssistant"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9")
    ],
    targets: [
        .executableTarget(
            name: "MeetingAssistant",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources"
        )
    ]
)
