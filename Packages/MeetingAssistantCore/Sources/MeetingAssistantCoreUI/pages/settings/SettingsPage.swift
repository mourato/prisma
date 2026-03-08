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
    private enum ToolbarLayout {
        static let transcriptionsSearchWidth: CGFloat = 230
        static let transcriptionsSearchHeight: CGFloat = AppDesignSystem.Layout.compactButtonHeight
    }

    fileprivate enum ChromeMode {
        case automatic
        case toolbar
        case embedded
        case none
    }

    private let chromeMode: ChromeMode
    @State private var selectedSection: SettingsSection = .metrics
    @State private var metricsNavigationState = SettingsSubpageNavigationState<MetricsDashboardRoute>()
    @State private var transcriptionsNavigationHistory = TranscriptionsNavigationHistory()
    @State private var transcriptionsSearchText = ""
    @State private var meetingNavigationState = MeetingSettingsNavigationState()
    @State private var enhancementsNavigationState = SettingsSubpageNavigationState<EnhancementsSettingsRoute>()
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
        .padding(.vertical, 2)
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
                glassNavigationPill
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .principal) {
                toolbarSectionTitle
            }
            .sharedBackgroundVisibility(.hidden)

            if shouldShowTranscriptionsSearch {
                ToolbarItem(placement: .primaryAction) {
                    transcriptionsToolbarSearchField
                }
                .sharedBackgroundVisibility(.hidden)
            }
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

    private var shouldShowTranscriptionsSearch: Bool {
        selectedSection == .transcriptions && transcriptionsNavigationHistory.currentRoute == .list
    }

    @available(macOS 26.0, *)
    private var tahoeDetailNavigationBar: some View {
        HStack(spacing: 8) {
            glassNavigationPill
            toolbarSectionTitle
            if shouldShowTranscriptionsSearch {
                Spacer()
                transcriptionsToolbarSearchField
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    @available(macOS 26.0, *)
    private var toolbarSectionTitle: some View {
        HStack(spacing: 6) {
            Image(systemName: selectedSection.icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 14, height: 14)

            Text(selectedSection.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .glassEffect(in: Capsule())
    }

    private var legacyDetailNavigationBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
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

            if shouldShowTranscriptionsSearch {
                transcriptionsSearchField
                    .frame(width: ToolbarLayout.transcriptionsSearchWidth)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @available(macOS 26.0, *)
    private var transcriptionsToolbarSearchField: some View {
        transcriptionsSearchField
            .frame(width: ToolbarLayout.transcriptionsSearchWidth)
    }

    private var transcriptionsSearchField: some View {
        NativeSearchField(
            text: $transcriptionsSearchText,
            placeholder: "settings.transcriptions.search_placeholder".localized
        )
        .frame(height: ToolbarLayout.transcriptionsSearchHeight)
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
                .padding(.vertical, 6)

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
        if selectedSection == .metrics, metricsNavigationState.canGoBack {
            _ = metricsNavigationState.goBack()
            return
        }

        if selectedSection == .transcriptions, transcriptionsNavigationHistory.canGoBack {
            _ = transcriptionsNavigationHistory.goBack()
            return
        }

        if selectedSection == .meetings, meetingNavigationState.canGoBack {
            _ = meetingNavigationState.goBack()
            return
        }

        if selectedSection == .enhancements, enhancementsNavigationState.canGoBack {
            _ = enhancementsNavigationState.goBack()
            return
        }
    }

    private func navigateForward() {
        if selectedSection == .metrics, metricsNavigationState.canGoForward {
            _ = metricsNavigationState.goForward()
            return
        }

        if selectedSection == .transcriptions, transcriptionsNavigationHistory.canGoForward {
            _ = transcriptionsNavigationHistory.goForward()
            return
        }

        if selectedSection == .meetings, meetingNavigationState.canGoForward {
            _ = meetingNavigationState.goForward()
            return
        }

        if selectedSection == .enhancements, enhancementsNavigationState.canGoForward {
            _ = enhancementsNavigationState.goForward()
            return
        }
    }

    private func selectSection(_ section: SettingsSection) {
        if selectedSection == .transcriptions, section != .transcriptions {
            transcriptionsSearchText = ""
        }
        selectedSection = section
    }

    private var canNavigateBack: Bool {
        if selectedSection == .metrics {
            return metricsNavigationState.canGoBack
        }

        if selectedSection == .transcriptions {
            return transcriptionsNavigationHistory.canGoBack
        }

        if selectedSection == .meetings {
            return meetingNavigationState.canGoBack
        }

        if selectedSection == .enhancements {
            return enhancementsNavigationState.canGoBack
        }

        return false
    }

    private var canNavigateForward: Bool {
        if selectedSection == .metrics {
            return metricsNavigationState.canGoForward
        }

        if selectedSection == .transcriptions {
            return transcriptionsNavigationHistory.canGoForward
        }

        if selectedSection == .meetings {
            return meetingNavigationState.canGoForward
        }

        if selectedSection == .enhancements {
            return enhancementsNavigationState.canGoForward
        }

        return false
    }

    @MainActor
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .metrics:
            MetricsDashboardSettingsTab(navigationState: $metricsNavigationState)
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
            TranscriptionsSettingsTab(
                searchText: $transcriptionsSearchText,
                navigationHistory: $transcriptionsNavigationHistory
            )
        case .enhancements:
            EnhancementsSettingsTab(navigationState: $enhancementsNavigationState)
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
        HStack(spacing: 8) {
            previewNavigationControls
            previewSectionTitle
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 900, alignment: .leading)
    }

    private var previewNavigationControls: some View {
        HStack(spacing: 2) {
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
