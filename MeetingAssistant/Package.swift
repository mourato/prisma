// swift-tools-version: 6.0
// Swift Package Manager configuration for MeetingAssistant

import PackageDescription

let package = Package(
    name: "MeetingAssistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MeetingAssistant",
            targets: ["MeetingAssistant"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MeetingAssistant",
            dependencies: [],
            path: "Sources"
        )
    ]
)
