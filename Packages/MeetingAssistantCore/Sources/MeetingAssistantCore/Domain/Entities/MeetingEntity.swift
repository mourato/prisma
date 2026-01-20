// MeetingEntity - Domain Entity pura sem dependências de UI/frameworks

import Foundation

/// Representa um aplicativo de reunião que pode ser detectado.
public enum DomainMeetingApp: String, CaseIterable, Codable, Sendable {
    case googleMeet = "google-meet"
    case microsoftTeams = "microsoft-teams"
    case slack
    case zoom
    case importedFile = "imported-file"
    case unknown

    /// Bundle identifiers para detectar este app.
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

    /// Padrões de título de janela para detectar reunião em andamento.
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
        case .importedFile: NSLocalizedString("meeting.app.imported", bundle: .safeModule, comment: "Imported File")
        case .unknown: NSLocalizedString("meeting.app.unknown", bundle: .safeModule, comment: "Unknown App")
        }
    }

    public var iconName: String {
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

/// Representa uma reunião ativa ou completada.
public struct MeetingEntity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let app: DomainMeetingApp
    public let startTime: Date
    public var endTime: Date?
    public var audioFilePath: String?

    public init(
        id: UUID = UUID(),
        app: DomainMeetingApp,
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

    /// Duração da reunião em segundos.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// String de duração formatada (ex: "1h 23m").
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

    public var appName: String { app.displayName }
    public var appIconName: String { app.iconName }
}
