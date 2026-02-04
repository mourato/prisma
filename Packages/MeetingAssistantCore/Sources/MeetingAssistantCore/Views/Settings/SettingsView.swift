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
    @State private var selectedSection: SettingsSection = .metrics
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    @MainActor
    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()

                detailView
            }
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
                    sidebarItem(for: section)
                        .tag(section)
                }
            } header: {
                Text(NSLocalizedString("about.title", bundle: .safeModule, comment: ""))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .listStyle(.sidebar)
        .tint(SettingsDesignSystem.Colors.accent)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
        )
    }

    private func sidebarItem(for section: SettingsSection) -> some View {
        Label {
            Text(section.title)
                .font(.body)
                .padding(.leading, 4)
        } icon: {
            Image(systemName: section.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selectedSection == section ? .white : SettingsDesignSystem.Colors.accent)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedSection == section ? SettingsDesignSystem.Colors.accent : SettingsDesignSystem.Colors.accent.opacity(0.1))
                )
        }
        .padding(.vertical, 2)
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
        case .assistant:
            AssistantSettingsTab()
        case .transcriptions:
            TranscriptionsSettingsTab()
        case .aiModels:
            AISettingsTab()
        case .permissions:
            PermissionsSettingsTab()
        }
    }
}

#Preview {
    SettingsView()
}
