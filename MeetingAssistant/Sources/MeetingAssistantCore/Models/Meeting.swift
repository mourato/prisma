import Foundation
import SwiftUI

/// Represents a meeting app that can be detected.
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
        case .importedFile: NSLocalizedString("meeting.app.imported", comment: "Imported File")
        case .unknown: NSLocalizedString("meeting.app.unknown", comment: "Unknown App")
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

    public var color: Color {
        switch self {
        case .googleMeet: .green
        case .microsoftTeams: .purple
        case .slack: .pink
        case .zoom: .blue
        case .importedFile: .orange
        case .unknown: .gray
        }
    }
}

/// Represents an active or completed meeting.
public struct Meeting: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let app: MeetingApp
    public let startTime: Date
    public var endTime: Date?
    public var audioFilePath: String?

    public init(
        id: UUID = UUID(),
        app: MeetingApp,
        startTime: Date = Date(),
        endTime: Date? = nil,
        audioFilePath: String? = nil
    ) {
        self.id = id
        self.app = app
        self.startTime = startTime
        self.endTime = endTime
        self.audioFilePath = audioFilePath
    }

    /// Duration of the meeting in seconds.
    public var duration: TimeInterval {
        let end = self.endTime ?? Date()
        return end.timeIntervalSince(self.startTime)
    }

    /// Formatted duration string (e.g., "1h 23m").
    public var formattedDuration: String {
        let seconds = Int(duration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public var appName: String { self.app.displayName }
    public var appIcon: String { self.app.icon }
    public var appColor: Color { self.app.color }
}
