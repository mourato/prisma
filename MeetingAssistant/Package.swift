// swift-tools-version: 6.0
// Swift Package Manager configuration for MeetingAssistant

import PackageDescription

let package = Package(
    name: "MeetingAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MeetingAssistantCore",
            targets: ["MeetingAssistantCore"]
        ),
        .executable(
            name: "MeetingAssistant",
            targets: ["MeetingAssistant"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9")
    ],
    targets: [
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources/MeetingAssistantCore"
        ),
        .executableTarget(
            name: "MeetingAssistant",
            dependencies: [
                "MeetingAssistantCore"
            ],
            path: "Sources/MeetingAssistant"
        )
    ]
)
