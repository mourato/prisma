import SwiftUI

public struct MACallout: View {
    public enum Kind {
        case info
        case warning
        case error

        var symbolName: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        }

        var tintColor: Color {
            switch self {
            case .info: MeetingAssistantDesignSystem.Colors.accent
            case .warning: MeetingAssistantDesignSystem.Colors.warning
            case .error: MeetingAssistantDesignSystem.Colors.error
            }
        }

        var backgroundColor: Color {
            tintColor.opacity(0.1)
        }

        var strokeColor: Color {
            tintColor.opacity(0.2)
        }
    }

    private let kind: Kind
    private let title: String
    private let message: String

    public init(kind: Kind, title: String, message: String) {
        self.kind = kind
        self.title = title
        self.message = message
    }

    public var body: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Image(systemName: kind.symbolName)
                .font(.title2)
                .foregroundStyle(kind.tintColor)

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing16)
        .background(kind.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius)
                .stroke(kind.strokeColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
