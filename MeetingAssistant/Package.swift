// swift-tools-version: 6.0
// Swift Package Manager configuration for MeetingAssistant

import PackageDescription

let package = Package(
    name: "MeetingAssistant",
    defaultLocalization: "pt",
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
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.2.0")),
    ],
    targets: [
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            resources: [
                .process("Resources")
            ],

        ),
        .executableTarget(
            name: "MeetingAssistant",
            dependencies: [
                "MeetingAssistantCore"
            ],
            path: "Sources/MeetingAssistant"
        ),
        .testTarget(
            name: "MeetingAssistantTests",
            dependencies: ["MeetingAssistantCore"],
            path: "Tests/MeetingAssistantTests"
        ),
    ]
)
