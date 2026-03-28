import Foundation

public enum CapturePurpose: String, CaseIterable, Codable, Sendable {
    case dictation
    case meeting

    public static func defaultValue(for app: MeetingApp) -> CapturePurpose {
        switch app {
        case .unknown:
            .dictation
        case .importedFile:
            .meeting
        default:
            .meeting
        }
    }

    public static func defaultValue(for app: DomainMeetingApp) -> CapturePurpose {
        switch app {
        case .unknown:
            .dictation
        case .importedFile:
            .meeting
        default:
            .meeting
        }
    }
}
