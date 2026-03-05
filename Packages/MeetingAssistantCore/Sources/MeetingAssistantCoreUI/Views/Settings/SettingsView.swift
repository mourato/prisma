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
    @State private var sectionNavigationHistory = SettingsSectionNavigationHistory(initialSection: .metrics)
    @State private var transcriptionsNavigationHistory = TranscriptionsNavigationHistory()
    @State private var meetingNavigationState = MeetingSettingsNavigationState()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @StateObject private var navigationService = NavigationService.shared

    @MainActor
    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            ZStack {
                AppDesignSystem.Colors.windowBackground
                    .ignoresSafeArea()

                detailView
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                detailNavigationBar
            }
            .tint(AppDesignSystem.Colors.accent)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(selectedSection.title)
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let sectionId = navigationService.requestedSettingsSection,
               let section = SettingsSection(rawValue: sectionId)
            {
                selectSection(section, pushHistory: true)
                navigationService.requestedSettingsSection = nil
            }
        }
        .onReceive(navigationService.$requestedSettingsSection.compactMap(\.self)) { sectionId in
            if let section = SettingsSection(rawValue: sectionId) {
                selectSection(section, pushHistory: true)
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
                selectSection(newSection, pushHistory: true)
            }
        )
    }

    // MARK: - Detail View

    private var detailNavigationBar: some View {
        HStack(spacing: AppDesignSystem.Layout.spacing12) {
            HStack(spacing: AppDesignSystem.Layout.spacing6) {
                navigationHistoryButton(
                    systemImage: "chevron.left",
                    helpKey: "transcription.qa.navigation.back",
                    isEnabled: canNavigateBack,
                    action: navigateBack
                )

                navigationHistoryButton(
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

    private func navigationHistoryButton(
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

        guard let section = sectionNavigationHistory.goBack() else { return }
        selectSection(section, pushHistory: false)
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

        guard let section = sectionNavigationHistory.goForward() else { return }
        selectSection(section, pushHistory: false)
    }

    private func selectSection(_ section: SettingsSection, pushHistory: Bool) {
        if pushHistory {
            sectionNavigationHistory.push(section)
        }
        selectedSection = section
    }

    private var canNavigateBack: Bool {
        if selectedSection == .transcriptions {
            return transcriptionsNavigationHistory.canGoBack || sectionNavigationHistory.canGoBack
        }

        if selectedSection == .meetings {
            return meetingNavigationState.canGoBack || sectionNavigationHistory.canGoBack
        }

        return sectionNavigationHistory.canGoBack
    }

    private var canNavigateForward: Bool {
        if selectedSection == .transcriptions {
            return transcriptionsNavigationHistory.canGoForward || sectionNavigationHistory.canGoForward
        }

        if selectedSection == .meetings {
            return meetingNavigationState.canGoForward || sectionNavigationHistory.canGoForward
        }

        return sectionNavigationHistory.canGoForward
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

#Preview {
    SettingsView()
}
