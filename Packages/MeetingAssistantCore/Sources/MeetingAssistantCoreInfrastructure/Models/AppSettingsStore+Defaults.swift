import Foundation
import MeetingAssistantCoreDomain

// MARK: - Default Values

extension AppSettingsStore {
    /// Default list of apps that should force Markdown formatting for dictation.
    public static let defaultMarkdownTargetBundleIdentifiers: [String] = [
        "abnerworks.Typora",
        "com.microsoft.VSCode",
        "com.uranusjr.macdown",
        "md.obsidian",
        "net.shinyfrog.bear",
    ]

    /// Default per-app dictation rules.
    public static let defaultDictationAppRules: [DictationAppRule] = defaultMarkdownTargetBundleIdentifiers.map {
        DictationAppRule(bundleIdentifier: $0, forceMarkdownOutput: true, outputLanguage: .original)
    }

    /// Default list of websites that should force Markdown formatting for dictation.
    public static let defaultMarkdownWebTargets: [WebContextTarget] = []

    /// Default list of browsers used for web target matching.
    public static let defaultWebTargetBrowserBundleIdentifiers: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
    ]

    /// Default list of apps monitored to start/stop meeting recordings.
    public static let defaultMonitoredMeetingBundleIdentifiers: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
        "net.whatsapp.WhatsApp",
        "us.zoom.xos",
    ]

    /// Default list of web meeting targets detected via browser URL matching.
    public static let defaultWebMeetingTargets: [WebMeetingTarget] = [
        WebMeetingTarget(
            app: .googleMeet,
            displayName: "Google Meet",
            urlPatterns: ["meet.google.com"],
            browserBundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        ),
        WebMeetingTarget(
            app: .microsoftTeams,
            displayName: "Microsoft Teams",
            urlPatterns: ["teams.microsoft.com"],
            browserBundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        ),
        WebMeetingTarget(
            app: .zoom,
            displayName: "Zoom",
            urlPatterns: ["zoom.us/j", "zoom.us/wc"],
            browserBundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        ),
    ]

    public static let defaultShortcutDoubleTapIntervalMilliseconds: Double = 350
    public static let shortcutDoubleTapIntervalRangeMilliseconds: ClosedRange<Double> = 150...1_000
}
