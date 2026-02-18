import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct PromptSelectionRow<MenuContent: View>: View {
    private let iconSystemName: String
    private let title: String
    private let description: String?
    private let isSelected: Bool
    private let onSelect: (() -> Void)?
    private let unselectedStrokeColor: Color
    private let showMenu: Bool
    private let preserveMenuSpacing: Bool
    private let menuContent: () -> MenuContent

    public init(
        iconSystemName: String,
        title: String,
        description: String?,
        isSelected: Bool,
        onSelect: (() -> Void)?,
        unselectedStrokeColor: Color = .clear,
        showMenu: Bool = true,
        preserveMenuSpacing: Bool = false,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.unselectedStrokeColor = unselectedStrokeColor
        self.showMenu = showMenu
        self.preserveMenuSpacing = preserveMenuSpacing
        self.menuContent = menuContent
    }

    public var body: some View {
        Group {
            if let onSelect {
                Button(action: onSelect) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .background(isSelected ? MeetingAssistantDesignSystem.Colors.selectionFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius)
                .stroke(isSelected ? MeetingAssistantDesignSystem.Colors.selectionStroke : unselectedStrokeColor, lineWidth: 1)
        )
        .contextMenu {
            menuContent()
        }
    }

    private var rowContent: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            promptIcon
            promptInfo

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
            }

            trailingMenu
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing10)
        .contentShape(Rectangle())
    }

    private var promptIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                .fill(isSelected ? MeetingAssistantDesignSystem.Colors.accent : MeetingAssistantDesignSystem.Colors.subtleFill)
                .frame(width: 36, height: 36)

            Image(systemName: iconSystemName)
                .font(.subheadline)
                .foregroundStyle(isSelected ? MeetingAssistantDesignSystem.Colors.onAccent : .primary)
        }
    }

    private var promptInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .bold : .medium)

            if let description {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trailingMenu: some View {
        if showMenu {
            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .highPriorityGesture(TapGesture())
        } else if preserveMenuSpacing {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
                .opacity(0)
        }
    }
}

#Preview {
    PromptSelectionRow(
        iconSystemName: "sparkles",
        title: "Example Prompt",
        description: "Description",
        isSelected: true,
        onSelect: {},
        showMenu: true
    ) {
        Button("Select") {}
    }
    .padding()
}
