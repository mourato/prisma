import Foundation
import SwiftUI

/// Represents a meeting app that can be detected.
enum MeetingApp: String, CaseIterable, Codable {
    case googleMeet = "google-meet"
    case microsoftTeams = "microsoft-teams"
    case slack = "slack"
    case zoom = "zoom"
    case unknown = "unknown"
    
    /// Bundle identifiers to detect this app.
    var bundleIdentifiers: [String] {
        switch self {
        case .googleMeet:
            return ["com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac"]
        case .microsoftTeams:
            return ["com.microsoft.teams", "com.microsoft.teams2"]
        case .slack:
            return ["com.tinyspeck.slackmacgap"]
        case .zoom:
            return ["us.zoom.xos"]
        case .unknown:
            return []
        }
    }
    
    /// Window title patterns to detect meeting in progress.
    var windowTitlePatterns: [String] {
        switch self {
        case .googleMeet:
            return ["meet.google.com", "Google Meet"]
        case .microsoftTeams:
            return ["Microsoft Teams", "| Teams"]
        case .slack:
            return ["Huddle", "Call"]
        case .zoom:
            return ["Zoom Meeting", "Zoom Webinar"]
        case .unknown:
            return []
        }
    }
    
    var displayName: String {
        switch self {
        case .googleMeet: return "Google Meet"
        case .microsoftTeams: return "Microsoft Teams"
        case .slack: return "Slack"
        case .zoom: return "Zoom"
        case .unknown: return "Desconhecido"
        }
    }
    
    var icon: String {
        switch self {
        case .googleMeet: return "video.fill"
        case .microsoftTeams: return "person.3.fill"
        case .slack: return "number.square.fill"
        case .zoom: return "video.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .googleMeet: return .green
        case .microsoftTeams: return .purple
        case .slack: return .pink
        case .zoom: return .blue
        case .unknown: return .gray
        }
    }
}

/// Represents an active or completed meeting.
struct Meeting: Identifiable, Codable, Hashable {
    let id: UUID
    let app: MeetingApp
    let startTime: Date
    var endTime: Date?
    var audioFilePath: String?
    
    init(
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
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    /// Formatted duration string (e.g., "1h 23m").
    var formattedDuration: String {
        let seconds = Int(duration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var appName: String { app.displayName }
    var appIcon: String { app.icon }
    var appColor: Color { app.color }
}
