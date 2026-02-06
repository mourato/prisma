import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 640
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 260
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Uses sidebar navigation pattern similar to macOS System Settings.
public struct SettingsView: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @State private var selectedSection: SettingsSection = .metrics
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    @MainActor
    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            ZStack {
                MeetingAssistantDesignSystem.Colors.windowBackground
                    .ignoresSafeArea()

                detailView
            }
            .tint(MeetingAssistantDesignSystem.Colors.accent)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(selectedSection.title)
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.sidebarContainerCornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.sidebarContainerCornerRadius)
                        .fill(MeetingAssistantDesignSystem.Colors.windowBackground.opacity(0.58))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.sidebarContainerCornerRadius)
                        .strokeBorder(
                            MeetingAssistantDesignSystem.Colors.separator.opacity(0.32),
                            lineWidth: 0.5
                        )
                )

            ScrollView {
                LazyVStack(spacing: MeetingAssistantDesignSystem.Layout.sidebarSectionSpacing) {
                    ForEach(SettingsSection.allCases) { section in
                        SidebarItemView(
                            section: section,
                            isSelected: selectedSection == section,
                            onSelect: { selectedSection = section }
                        )
                    }
                }
                .padding(.top, MeetingAssistantDesignSystem.Layout.sidebarTopInset)
                .padding(.horizontal, MeetingAssistantDesignSystem.Layout.sidebarHorizontalPadding)
                .padding(.bottom, MeetingAssistantDesignSystem.Layout.sidebarVerticalPadding)
            }
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing10)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
        )
    }

    // MARK: - Detail View

    @MainActor
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .metrics:
            MetricsDashboardSettingsTab()
        case .general:
            GeneralSettingsTab()
        case .dictation:
            DictationSettingsTab()
        case .meetings:
            MeetingSettingsTab()
        case .assistant:
            AssistantSettingsTab()
        case .audio:
            AudioSettingsTab()
        case .transcriptions:
            TranscriptionsSettingsTab()
        case .enhancements:
            EnhancementsSettingsTab()
        case .service:
            ServiceSettingsTab()
        case .permissions:
            PermissionsSettingsTab()
        }
    }
}

// MARK: - Sidebar Item View

private struct SidebarItemView: View {
    let section: SettingsSection
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.sidebarItemContentSpacing) {
                Image(systemName: section.icon)
                    .font(
                        .system(
                            size: MeetingAssistantDesignSystem.Layout.sidebarSymbolFontSize,
                            weight: .medium
                        )
                    )
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(width: 24, height: 24)

                Text(section.title)
                    .font(
                        .system(
                            size: MeetingAssistantDesignSystem.Layout.sidebarLabelFontSize,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .frame(height: MeetingAssistantDesignSystem.Layout.sidebarItemHeight)
            .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
            .background(isSelected ? MeetingAssistantDesignSystem.Colors.selectionFill : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.sidebarItemCornerRadius)
                    .stroke(
                        isSelected ? MeetingAssistantDesignSystem.Colors.selectionStroke : .clear,
                        lineWidth: 1
                    )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.sidebarItemCornerRadius)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
}
