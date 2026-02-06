import SwiftUI

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 640
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 280
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
        List(selection: $selectedSection) {
            Section {
                ForEach(SettingsSection.allCases) { section in
                    SidebarItemView(
                        section: section,
                        isSelected: selectedSection == section,
                        accentColor: MeetingAssistantDesignSystem.Colors.accent,
                        onAccentColor: MeetingAssistantDesignSystem.Colors.onAccent
                    )
                    .tag(section)
                    .listRowBackground(
                        selectedSection == section ? MeetingAssistantDesignSystem.Colors.accent : nil
                    )
                }
            } header: {
                Text("about.title".localized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .listStyle(.sidebar)
        .tint(MeetingAssistantDesignSystem.Colors.accent)
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
    let accentColor: Color
    let onAccentColor: Color

    var body: some View {
        Label {
            Text(section.title)
                .font(.body)
                .padding(.leading, MeetingAssistantDesignSystem.Layout.spacing4)
                .foregroundStyle(isSelected ? onAccentColor : .primary)
        } icon: {
            ZStack {
                RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.chipCornerRadius)
                    .fill(accentColor)
                    .opacity(isSelected ? 1.0 : 0.1)

                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(isSelected ? onAccentColor : accentColor)
            }
            .frame(width: 24, height: 24)
        }
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing2)
    }
}

#Preview {
    SettingsView()
}
