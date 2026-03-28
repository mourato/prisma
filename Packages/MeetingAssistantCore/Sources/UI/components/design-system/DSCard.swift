import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DSCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        cornerRadius: CGFloat = AppDesignSystem.Layout.cardCornerRadius,
        padding: CGFloat = AppDesignSystem.Layout.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppDesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppDesignSystem.Colors.cardStroke, lineWidth: 0.5)
                )
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("DSCard") {
    DSCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Design System Card")
                .font(.headline)
            Text("A reusable card with a subtle material background and corner treatment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 280)
}
