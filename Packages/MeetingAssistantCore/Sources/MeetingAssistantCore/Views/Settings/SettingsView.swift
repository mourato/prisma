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
    @State private var selectedSection: SettingsSection = .general
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: self.$columnVisibility) {
            self.sidebar
        } detail: {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()

                self.detailView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .animation(.spring(duration: 0.3), value: self.selectedSection)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(self.selectedSection.title)
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: self.$selectedSection) {
            Section {
                ForEach(SettingsSection.allCases) { section in
                    self.sidebarItem(for: section)
                        .tag(section)
                }
            } header: {
                Text("Meeting Assistant")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
        )
    }

    @ViewBuilder
    private func sidebarItem(for section: SettingsSection) -> some View {
        Label {
            Text(section.title)
                .font(.body)
                .padding(.leading, 4)
        } icon: {
            Image(systemName: section.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(self.selectedSection == section ? .white : Color.accentColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(self.selectedSection == section ? Color.accentColor : Color.accentColor.opacity(0.1))
                )
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch self.selectedSection {
        case .general:
            GeneralSettingsTab()
        case .transcriptions:
            TranscriptionsSettingsTab()
        case .postProcessing:
            PostProcessingSettingsTab()
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
