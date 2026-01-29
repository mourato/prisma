// swift-tools-version: 6.0
// Swift Package for MeetingAssistantCore library

import PackageDescription

let package = Package(
    name: "MeetingAssistantCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MeetingAssistantCore",
            targets: ["MeetingAssistantCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.10.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/Brightify/Cuckoo.git", from: "2.0.0"),
        .package(url: "https://github.com/dmrschmidt/DSWaveformImage", from: "14.0.0"),
    ],
    targets: [
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "DSWaveformImageViews", package: "DSWaveformImage"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MeetingAssistantCoreTests",
            dependencies: [
                "MeetingAssistantCore",
                .product(name: "Cuckoo", package: "Cuckoo"),
            ],
            path: "Tests/MeetingAssistantCoreTests"
        ),
    ]
)
