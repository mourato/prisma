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
    fileprivate enum ChromeMode {
        case automatic
        case toolbar
        case embedded
        case none
    }

    private let chromeMode: ChromeMode
    @State private var selectedSection: SettingsSection = .metrics
    @State private var transcriptionsNavigationHistory = TranscriptionsNavigationHistory()
    @State private var meetingNavigationState = MeetingSettingsNavigationState()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @StateObject private var navigationService = NavigationService.shared

    @MainActor
    public init() {
        chromeMode = .automatic
    }

    @MainActor
    fileprivate init(chromeMode: ChromeMode) {
        self.chromeMode = chromeMode
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            ZStack {
                AppDesignSystem.Colors.windowBackground
                    .ignoresSafeArea()

                detailView
            }
            .modifier(SettingsDetailChromeModifier(legacyHeader: detailNavigationBar))
            .tint(AppDesignSystem.Colors.accent)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            if usesToolbarChrome {
                settingsToolbarContent
            }
        }
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let sectionId = navigationService.requestedSettingsSection,
               let section = SettingsSection(rawValue: sectionId)
            {
                selectSection(section)
                navigationService.requestedSettingsSection = nil
            }
        }
        .onReceive(navigationService.$requestedSettingsSection.compactMap(\.self)) { sectionId in
            if let section = SettingsSection(rawValue: sectionId) {
                selectSection(section)
            }
            navigationService.requestedSettingsSection = nil
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: sidebarSelectionBinding) {
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
        HStack(spacing: 8) {
            Image(systemName: section.icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(section.sidebarIconBackgroundColor)
                )
                .shadow(
                    color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1
                )
            Text(section.title)
                .font(
                    .system(
                        size: AppDesignSystem.Layout.sidebarLabelFontSize,
                        weight: .regular
                    )
                )
                .lineLimit(1)
        }
        .padding(.vertical, AppDesignSystem.Layout.spacing2)
    }

    private var sidebarSelectionBinding: Binding<SettingsSection> {
        Binding(
            get: { selectedSection },
            set: { newSection in
                selectSection(newSection)
            }
        )
    }

    // MARK: - Detail View

    private var usesToolbarChrome: Bool {
        switch chromeMode {
        case .toolbar:
            return true
        case .embedded, .none:
            return false
        case .automatic:
            guard #available(macOS 26.0, *) else {
                return false
            }
            return !PreviewRuntime.isRunning
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbarContent: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) {
                toolbarChromeContent
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    @ViewBuilder
    private var detailNavigationBar: some View {
        if #available(macOS 26.0, *), showsEmbeddedTahoeChrome {
            tahoeDetailNavigationBar
        } else if shouldShowLegacyChrome {
            legacyDetailNavigationBar
        }
    }

    private var showsEmbeddedTahoeChrome: Bool {
        guard #available(macOS 26.0, *) else {
            return false
        }

        switch chromeMode {
        case .embedded:
            return true
        case .automatic:
            return !usesToolbarChrome
        case .toolbar, .none:
            return false
        }
    }

    private var shouldShowLegacyChrome: Bool {
        switch chromeMode {
        case .none, .toolbar:
            return false
        case .embedded, .automatic:
            return !showsEmbeddedTahoeChrome
        }
    }

    @available(macOS 26.0, *)
    private var toolbarChromeContent: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing8) {
            glassNavigationPill
            toolbarSectionTitle
        }
    }

    @available(macOS 26.0, *)
    private var tahoeDetailNavigationBar: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing8) {
            glassNavigationPill
            toolbarSectionTitle
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDesignSystem.Layout.spacing10)
        .padding(.top, AppDesignSystem.Layout.spacing6)
        .padding(.bottom, AppDesignSystem.Layout.spacing6)
    }

    @available(macOS 26.0, *)
    private var toolbarSectionTitle: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing6) {
            Image(systemName: selectedSection.icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 14, height: 14)

            Text(selectedSection.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
            .padding(.horizontal, AppDesignSystem.Layout.spacing10)
            .padding(.vertical, AppDesignSystem.Layout.spacing10)
            .glassEffect(in: Capsule())
    }
    
    private var legacyDetailNavigationBar: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing12) {
            HStack(spacing: AppDesignSystem.Layout.spacing6) {
                legacyNavigationHistoryButton(
                    systemImage: "chevron.left",
                    helpKey: "transcription.qa.navigation.back",
                    isEnabled: canNavigateBack,
                    action: navigateBack
                )

                legacyNavigationHistoryButton(
                    systemImage: "chevron.right",
                    helpKey: "transcription.qa.navigation.forward",
                    isEnabled: canNavigateForward,
                    action: navigateForward
                )
            }

            Text(selectedSection.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDesignSystem.Layout.spacing16)
        .padding(.vertical, AppDesignSystem.Layout.spacing10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @available(macOS 26.0, *)
    private var glassNavigationPill: some View {
        HStack(spacing: 0) {
            toolbarNavigationButton(
                systemImage: "chevron.left",
                helpKey: "transcription.qa.navigation.back",
                isEnabled: canNavigateBack,
                action: navigateBack
            )
            
            Divider()
                .frame(height: 20)
                .padding(.vertical, AppDesignSystem.Layout.spacing6)

            toolbarNavigationButton(
                systemImage: "chevron.right",
                helpKey: "transcription.qa.navigation.forward",
                isEnabled: canNavigateForward,
                action: navigateForward
            )
        }
        .glassEffect(in: Capsule())
    }

    @available(macOS 26.0, *)
    private func toolbarNavigationButton(
        systemImage: String,
        helpKey: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary.opacity(0.75)))
        .opacity(isEnabled ? 1 : 0.65)
        .help(helpKey.localized)
        .accessibilityLabel(helpKey.localized)
        .disabled(!isEnabled)
    }

    private func legacyNavigationHistoryButton(
        systemImage: String,
        helpKey: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary.opacity(0.75)))
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AppDesignSystem.Colors.subtleFill)
        )
        .opacity(isEnabled ? 1 : 0.65)
        .help(helpKey.localized)
        .accessibilityLabel(helpKey.localized)
        .disabled(!isEnabled)
    }

    private func navigateBack() {
        if selectedSection == .transcriptions, transcriptionsNavigationHistory.canGoBack {
            _ = transcriptionsNavigationHistory.goBack()
            return
        }

        if selectedSection == .meetings, meetingNavigationState.canGoBack {
            _ = meetingNavigationState.goBack()
            return
        }
    }

    private func navigateForward() {
        if selectedSection == .transcriptions, transcriptionsNavigationHistory.canGoForward {
            _ = transcriptionsNavigationHistory.goForward()
            return
        }

        if selectedSection == .meetings, meetingNavigationState.canGoForward {
            _ = meetingNavigationState.goForward()
            return
        }
    }

    private func selectSection(_ section: SettingsSection) {
        selectedSection = section
    }

    private var canNavigateBack: Bool {
        if selectedSection == .transcriptions {
            return transcriptionsNavigationHistory.canGoBack
        }

        if selectedSection == .meetings {
            return meetingNavigationState.canGoBack
        }

        return false
    }

    private var canNavigateForward: Bool {
        if selectedSection == .transcriptions {
            return transcriptionsNavigationHistory.canGoForward
        }

        if selectedSection == .meetings {
            return meetingNavigationState.canGoForward
        }

        return false
    }

    @MainActor
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .metrics:
            MetricsDashboardSettingsTab()
        case .general:
            GeneralSettingsTab()
        case .rulesPerApp:
            RulesPerAppSettingsTab()
        case .vocabulary:
            VocabularySettingsTab()
        case .dictation:
            DictationSettingsTab()
        case .meetings:
            MeetingSettingsTab(navigationState: $meetingNavigationState)
        case .assistant:
            AssistantSettingsTab()
        case .integrations:
            AssistantSettingsTab()
        case .audio:
            AudioSettingsTab()
        case .transcriptions:
            TranscriptionsSettingsTab(navigationHistory: $transcriptionsNavigationHistory)
        case .enhancements:
            EnhancementsSettingsTab()
        case .permissions:
            PermissionsSettingsTab()
        }
    }

}

private struct SettingsDetailChromeModifier<LegacyHeader: View>: ViewModifier {
    let legacyHeader: LegacyHeader

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !PreviewRuntime.isRunning {
            content
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                legacyHeader
            }
        }
    }
}

private struct SettingsToolbarChromePreview: View {
    var body: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing8) {
            previewNavigationControls
            previewSectionTitle
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDesignSystem.Layout.spacing10)
        .padding(.vertical, AppDesignSystem.Layout.spacing6)
        .frame(width: 900, alignment: .leading)
    }

    private var previewNavigationControls: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing2) {
            previewNavButton("chevron.left")
            previewNavButton("chevron.right")
        }
    }

    private func previewNavButton(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }

    private var previewSectionTitle: some View {
        Label("settings.section.metrics".localized, systemImage: "chart.pie.fill")
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview("Toolbar", traits: .sizeThatFitsLayout) {
    SettingsToolbarChromePreview()
}

#Preview("Settings Content") {
    SettingsView(chromeMode: .none)
}
