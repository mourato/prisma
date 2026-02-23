import SwiftUI

public struct SettingsDrillDownListRow<Destination: Hashable>: View {
    private let destination: Destination
    private let title: String
    private let subtitle: String?
    private let accessibilityHint: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

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
        List {
            NavigationLink(value: destination) {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .scaleEffect(isHovering ? 1.01 : 1)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82),
                    value: isHovering
                )
            }
            .accessibilityElement(children: .combine)
            .modifier(OptionalAccessibilityHintModifier(accessibilityHint: accessibilityHint))
        }
        .listStyle(.inset)
        .scrollDisabled(true)
        .environment(\.defaultMinListRowHeight, subtitle == nil ? 40 : 56)
        .frame(minHeight: subtitle == nil ? 56 : 86)
        .onHover { hovering in
            isHovering = hovering
        }
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
