import SwiftUI

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 700
    static let windowHeight: CGFloat = 500
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 200
    static let sidebarMaxWidth: CGFloat = 220
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Uses sidebar navigation pattern similar to macOS System Settings.
public struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .transcriptions

    public init() {}

    public var body: some View {
        NavigationSplitView {
            self.sidebar
        } detail: {
            self.detailView
        }
        // Removed rigid constraints to allow user resizing and accessibility scaling
        // Default size will be determined by content or window definition
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
