import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct SettingsSelectableCard: View {
    private let iconSystemName: String
    private let title: String
    private let description: String?
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        iconSystemName: String,
        title: String,
        description: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                        .fill(isSelected ? AppDesignSystem.Colors.accent : AppDesignSystem.Colors.subtleFill)
                        .frame(width: 38, height: 38)

                    Image(systemName: iconSystemName)
                        .font(.headline)
                        .foregroundStyle(isSelected ? AppDesignSystem.Colors.onAccent : .secondary)
                }

                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(.primary)

                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(AppDesignSystem.Layout.cardPadding)
            .background(backgroundShape)
            .contentShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: AppDesignSystem.Layout.cardCornerRadius)
            .fill(isSelected ? AppDesignSystem.Colors.selectionFill : AppDesignSystem.Colors.subtleFill2)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.Layout.cardCornerRadius)
                    .stroke(
                        isSelected ? AppDesignSystem.Colors.selectionStroke : AppDesignSystem.Colors.settingsCardStroke,
                        lineWidth: 1
                    )
            )
    }
}

#Preview("Settings Selectable Card") {
    HStack(spacing: AppDesignSystem.Layout.spacing12) {
        SettingsSelectableCard(
            iconSystemName: "desktopcomputer",
            title: "System Default",
            description: "Use your Mac's default input device.",
            isSelected: true,
            action: {}
        )

        SettingsSelectableCard(
            iconSystemName: "mic.fill",
            title: "Custom Device",
            description: "Choose a specific microphone for each power state.",
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .frame(width: 560)
}
