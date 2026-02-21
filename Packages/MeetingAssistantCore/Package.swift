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
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.12.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0"),
    ],
    targets: [
        .target(
            name: "MeetingAssistantCoreCommon",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "MeetingAssistantCoreDomain",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreMocking",
            ]
        ),
        .target(
            name: "MeetingAssistantCoreData",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
            ]
        ),
        .target(
            name: "MeetingAssistantCoreInfrastructure",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreDomain",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .target(
            name: "MeetingAssistantCoreAudio",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .target(
            name: "MeetingAssistantCoreAI",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .target(
            name: "MeetingAssistantCoreUI",
            dependencies: [
                "MeetingAssistantCoreAI",
                "MeetingAssistantCoreAudio",
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                "MeetingAssistantCoreAI",
                "MeetingAssistantCoreAudio",
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                "MeetingAssistantCoreUI",
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
                "MeetingAssistantCoreAI",
                "MeetingAssistantCoreAudio",
                "MeetingAssistantCoreUI",
                "MeetingAssistantCoreDomain",
            ],
            path: "Tests/MeetingAssistantCoreTests",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
