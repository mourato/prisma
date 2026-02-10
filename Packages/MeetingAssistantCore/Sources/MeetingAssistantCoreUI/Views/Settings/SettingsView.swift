import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

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
        List(selection: $selectedSection) {
            Section("about.title".localized) {
                ForEach(SettingsSection.primarySections) { section in
                    NavigationLink(value: section) {
                        sidebarLabel(for: section)
                    }
                }
            }

            Section("settings.title".localized) {
                ForEach(SettingsSection.settingsSections) { section in
                    NavigationLink(value: section) {
                        sidebarLabel(for: section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
        )
    }

    private func sidebarLabel(for section: SettingsSection) -> some View {
        Label(section.title, systemImage: section.icon)
            .font(
                .system(
                    size: MeetingAssistantDesignSystem.Layout.sidebarLabelFontSize,
                    weight: .regular
                )
            )
            .lineLimit(1)
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing2)
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
        case .permissions:
            PermissionsSettingsTab()
        }
    }
}

#Preview {
    SettingsView()
}
