import SwiftUI

public struct SettingsDrillDownListRow<Destination: Hashable>: View {
    private let destination: Destination
    private let title: String
    private let subtitle: String?
    private let accessibilityHint: String?

    public init(
        destination: Destination,
        title: String,
        subtitle: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.destination = destination
        self.title = title
        self.subtitle = subtitle
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                    }
                }

                Spacer(minLength: MeetingAssistantDesignSystem.Layout.spacing8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 0)
            .padding(.vertical, subtitle == nil
                ? MeetingAssistantDesignSystem.Layout.spacing10
                : MeetingAssistantDesignSystem.Layout.spacing8)
            .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .modifier(OptionalAccessibilityHintModifier(accessibilityHint: accessibilityHint))
    }
}

private struct OptionalAccessibilityHintModifier: ViewModifier {
    let accessibilityHint: String?

    func body(content: Content) -> some View {
        if let accessibilityHint, !accessibilityHint.isEmpty {
            content.accessibilityHint(accessibilityHint)
        } else {
            content
        }
    }
}

#Preview("Drill-Down Row") {
    NavigationStack {
        SettingsDrillDownListRow(
            destination: 1,
            title: "Monitored apps and sites",
            subtitle: "Configure which apps and web targets are monitored to detect meetings automatically."
        )
        .padding()
        .navigationDestination(for: Int.self) { _ in
            Text("Detail")
        }
    }
}
