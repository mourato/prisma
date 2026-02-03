// swift-tools-version: 6.0
// Swift Package for MeetingAssistantCore library

import CompilerPluginSupport
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
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0"),
    ],
    targets: [
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Atomics", package: "swift-atomics"),
                "MeetingAssistantCoreMocking",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "MeetingAssistantCoreMocking",
            dependencies: [
                "MeetingAssistantCoreMockingMacros",
            ]
        ),
        .macro(
            name: "MeetingAssistantCoreMockingMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
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
