import SwiftUI

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 600
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 220
    static let sidebarMaxWidth: CGFloat = 260
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Uses sidebar navigation pattern similar to macOS System Settings.
public struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .transcriptions
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: self.$columnVisibility) {
            self.sidebar
        } detail: {
            self.detailView
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(self.selectedSection.title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                // This helps align the sidebar toggle with the traffic lights
                // in the title bar on macOS 13+.
            }
        }
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: self.$selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
        )
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch self.selectedSection {
        case .transcriptions:
            TranscriptionsSettingsTab()
        case .general:
            GeneralSettingsTab()
        case .shortcuts:
            ShortcutSettingsTab()
        case .ai:
            AISettingsTab()
        case .postProcessing:
            PostProcessingSettingsTab()
        case .service:
            ServiceSettingsTab()
        case .permissions:
            PermissionsSettingsTab()
        }
    }
}

#Preview {
    SettingsView()
}
