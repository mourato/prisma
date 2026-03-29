import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DSActionButton<Label: View>: View {
    public enum Kind {
        case primary
        case destructive
        case secondary

        var foreground: Color {
            switch self {
            case .primary: AppDesignSystem.Colors.onAccent
            case .destructive: Color.white
            case .secondary: Color.primary
            }
        }

        func background(isEnabled: Bool) -> AnyShapeStyle {
            switch self {
            case .primary:
                AnyShapeStyle(isEnabled ? AppDesignSystem.Colors.accent : Color.gray)
            case .destructive:
                AnyShapeStyle(isEnabled ? AppDesignSystem.Colors.error : Color.gray)
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
                .frame(maxWidth: .infinity, minHeight: AppDesignSystem.Layout.controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(kind.foreground.opacity(isEnabled ? 1 : 0.7))
        .background(kind.background(isEnabled: isEnabled))
        .clipShape(Capsule())
        .shadow(color: Color.primary.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}

#Preview("DSActionButton") {
    VStack(spacing: 12) {
        DSActionButton(kind: .primary, action: {}) {
            Text("Primary Action")
                .fontWeight(.semibold)
        }
        DSActionButton(kind: .secondary, action: {}) {
            Text("Secondary Action")
                .fontWeight(.semibold)
        }
        DSActionButton(kind: .destructive, action: {}) {
            Text("Destructive")
                .fontWeight(.semibold)
        }
        .disabled(true)
    }
    .padding()
    .frame(width: 240)
}
