import Foundation
import MeetingAssistantCoreCommon

/// Represents a meeting app that can be detected.
public enum MeetingApp: String, CaseIterable, Codable, Sendable {
    case googleMeet = "google-meet"
    case microsoftTeams = "microsoft-teams"
    case slack
    case zoom
    case importedFile = "imported-file"
    case unknown

    /// Bundle identifiers to detect this app.
    public var bundleIdentifiers: [String] {
        switch self {
        case .googleMeet:
            ["com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac"]
        case .microsoftTeams:
            ["com.microsoft.teams", "com.microsoft.teams2"]
        case .slack:
            ["com.tinyspeck.slackmacgap"]
        case .zoom:
            ["us.zoom.xos"]
        case .importedFile, .unknown:
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
        case .slack:
            ["Huddle", "Call"]
        case .zoom:
            ["Zoom Meeting", "Zoom Webinar"]
        case .importedFile, .unknown:
            []
        }
    }

    public var displayName: String {
        switch self {
        case .googleMeet: "Google Meet"
        case .microsoftTeams: "Microsoft Teams"
        case .slack: "Slack"
        case .zoom: "Zoom"
        case .importedFile: "meeting.app.imported".localized
        case .unknown: "meeting.app.unknown".localized
        }
    }

    public var icon: String {
        switch self {
        case .googleMeet: "video.fill"
        case .microsoftTeams: "person.3.fill"
        case .slack: "number.square.fill"
        case .zoom: "video.circle.fill"
        case .importedFile: "doc.badge.arrow.up"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Represents an active or completed meeting.
public struct Meeting: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let app: MeetingApp
    public var type: MeetingType = .general
    public var state: MeetingState = .idle
    public let startTime: Date
    public var endTime: Date?
    public var audioFilePath: String?

    public init(
        id: UUID = UUID(),
        app: MeetingApp,
        type: MeetingType = .general,
        state: MeetingState = .idle,
        startTime: Date = Date(),
        endTime: Date? = nil,
        audioFilePath: String? = nil
    ) {
        self.id = id
        self.app = app
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
        app.displayName
    }

    public var appIcon: String {
        app.icon
    }

    /// Indicates if the meeting represents a dictation (unknown app source).
    public var isDictation: Bool {
        app == .unknown
    }
}
