import Foundation
import MeetingAssistantCoreCommon

/// Represents a meeting app that can be detected.
public enum MeetingApp: String, CaseIterable, Codable, Sendable {
    case googleMeet = "google-meet"
    case microsoftTeams = "microsoft-teams"
    case discord
    case slack
    case whatsApp = "whatsapp"
    case zoom
    case manualMeeting = "manual-meeting"
    case importedFile = "imported-file"
    case unknown

    /// Bundle identifiers to detect this app.
    public var bundleIdentifiers: [String] {
        switch self {
        case .googleMeet:
            ["com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac"]
        case .microsoftTeams:
            ["com.microsoft.teams", "com.microsoft.teams2"]
        case .discord:
            ["com.hnc.Discord"]
        case .slack:
            ["com.tinyspeck.slackmacgap"]
        case .whatsApp:
            ["net.whatsapp.WhatsApp"]
        case .zoom:
            ["us.zoom.xos"]
        case .manualMeeting, .importedFile, .unknown:
            []
        }
    }

    /// Window title patterns to detect meeting in progress.
    public var windowTitlePatterns: [String] {
        switch self {
        case .googleMeet:
            ["meet.google.com", "Google Meet"]
        case .microsoftTeams:
            ["Microsoft Teams", "| Teams"]
        case .discord:
            []
        case .slack:
            ["Huddle", "Call"]
        case .whatsApp:
            []
        case .zoom:
            ["Zoom Meeting", "Zoom Webinar"]
        case .manualMeeting, .importedFile, .unknown:
            []
        }
    }

    public var displayName: String {
        switch self {
        case .googleMeet: "Google Meet"
        case .microsoftTeams: "Microsoft Teams"
        case .discord: "Discord"
        case .slack: "Slack"
        case .whatsApp: "WhatsApp"
        case .zoom: "Zoom"
        case .manualMeeting: "meeting.app.manual".localized
        case .importedFile: "meeting.app.imported".localized
        case .unknown: "meeting.app.unknown".localized
        }
    }

    public var icon: String {
        switch self {
        case .googleMeet: "video.fill"
        case .microsoftTeams: "person.3.fill"
        case .discord: "bubble.left.and.bubble.right.fill"
        case .slack: "number.square.fill"
        case .whatsApp: "phone.fill"
        case .zoom: "video.circle.fill"
        case .manualMeeting: "person.2.wave.2"
        case .importedFile: "doc.badge.arrow.up"
        case .unknown: "questionmark.circle"
        }
    }

    /// Whether this source should expose meeting-only conversation features.
    public var supportsMeetingConversation: Bool {
        self != .unknown && self != .importedFile
    }
}

/// Represents an active or completed meeting.
public struct Meeting: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let app: MeetingApp
    public let appBundleIdentifier: String?
    public let appDisplayName: String?
    public var type: MeetingType = .general
    public var state: MeetingState = .idle
    public let startTime: Date
    public var endTime: Date?
    public var audioFilePath: String?

    public init(
        id: UUID = UUID(),
        app: MeetingApp,
        appBundleIdentifier: String? = nil,
        appDisplayName: String? = nil,
        type: MeetingType = .general,
        state: MeetingState = .idle,
        startTime: Date = Date(),
        endTime: Date? = nil,
        audioFilePath: String? = nil
    ) {
        self.id = id
        self.app = app
        self.appBundleIdentifier = appBundleIdentifier
        self.appDisplayName = appDisplayName
        self.type = type
        self.state = state
        self.startTime = startTime
        self.endTime = endTime
        self.audioFilePath = audioFilePath
    }

    /// Duration of the meeting in seconds.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Formatted duration string (e.g., "1h 23m").
    public var formattedDuration: String {
        let seconds = Int(duration)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public var appName: String {
        let trimmed = appDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed! : app.displayName
    }

    public var appIcon: String {
        app.icon
    }

    /// Indicates if the meeting represents a dictation (unknown app source).
    public var isDictation: Bool {
        app == .unknown
    }
}
