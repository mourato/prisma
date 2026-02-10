import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MAActionButton<Label: View>: View {
    public enum Kind {
        case primary
        case destructive
        case secondary

        var foreground: Color {
            switch self {
            case .primary: MeetingAssistantDesignSystem.Colors.onAccent
            case .destructive: Color.white
            case .secondary: Color.primary
            }
        }

        func background(isEnabled: Bool) -> AnyShapeStyle {
            switch self {
            case .primary:
                AnyShapeStyle(isEnabled ? MeetingAssistantDesignSystem.Colors.accent : Color.gray)
            case .destructive:
                AnyShapeStyle(isEnabled ? MeetingAssistantDesignSystem.Colors.error : Color.gray)
            case .secondary:
                AnyShapeStyle(.ultraThinMaterial)
            }
        }
    }

    private let kind: Kind
    private let action: () -> Void
    private let label: Label

    @Environment(\.isEnabled) private var isEnabled

    public init(kind: Kind, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.kind = kind
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, minHeight: MeetingAssistantDesignSystem.Layout.controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(kind.foreground.opacity(isEnabled ? 1 : 0.7))
        .background(kind.background(isEnabled: isEnabled))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
