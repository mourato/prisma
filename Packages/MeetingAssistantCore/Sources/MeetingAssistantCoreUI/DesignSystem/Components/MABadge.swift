import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct MABadge: View {
    public enum Kind {
        case success
        case warning
        case error
        case neutral

        var background: Color {
            switch self {
            case .success: MeetingAssistantDesignSystem.Colors.success
            case .warning: MeetingAssistantDesignSystem.Colors.warning
            case .error: MeetingAssistantDesignSystem.Colors.error
            case .neutral: MeetingAssistantDesignSystem.Colors.neutral
            }
        }
    }

    private let text: String
    private let kind: Kind

    public init(_ text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    public var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(kind.background))
            .foregroundStyle(Color.white)
            .accessibilityLabel(text)
    }
}
