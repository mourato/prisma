import ProjectDescription

let project = Project(
    name: "MeetingAssistant",
    organizationName: "mourato",
    packages: [
        .package(path: "Packages/MeetingAssistantCore"),
    ],
    targets: [
        .target(
            name: "MeetingAssistant",
            destinations: .macOS,
            product: .app,
            bundleId: "com.meetingassistant.app",
            deploymentTargets: .macOS("14.0"),
            infoPlist: "App/Info.plist",
            sources: ["App/**/*.swift"],
            resources: ["App/Assets.xcassets", "App/**/*.lproj"],
            entitlements: "App/MeetingAssistant.entitlements",
            dependencies: [
                .package(product: "MeetingAssistantCore"),
                .target(name: "MeetingAssistantAI"),
            ]
        ),
        .target(
            name: "MeetingAssistantAI",
            destinations: .macOS,
            product: .xpc,
            bundleId: "com.mourato.my-meeting-assistant.ai-service",
            deploymentTargets: .macOS("14.0"),
            infoPlist: "MeetingAssistantAI/Resources/Info.plist",
            sources: ["MeetingAssistantAI/Sources/**/*.swift"],
            resources: [
                .glob(
                    pattern: "MeetingAssistantAI/Resources/**",
                    excluding: [
                        "MeetingAssistantAI/Resources/Info.plist",
                        "MeetingAssistantAI/Resources/MeetingAssistantAI.entitlements",
                    ]
                ),
            ],
            entitlements: "MeetingAssistantAI/Resources/MeetingAssistantAI.entitlements",
            dependencies: [
                .package(product: "MeetingAssistantCore"),
            ]
        ),
    ]
)
