import AppKit
import CoreGraphics
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum EnhancementsSettingsRoute: Hashable {
    case systemGuidelines
    case providerModels
}

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct EnhancementsSettingsTab: View {
    @StateObject private var viewModel: AISettingsViewModel
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel
    @Binding private var navigationState: SettingsSubpageNavigationState<EnhancementsSettingsRoute>
    @State private var supportStatus: TextContextSupportStatus = .unknown
    @State private var hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    @State private var systemGuidelinesDraft = ""
    private let supportChecker = TextContextSupportChecker()

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<SettingsSubpageNavigationState<EnhancementsSettingsRoute>> = .constant(SettingsSubpageNavigationState())
    ) {
        _viewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
        _navigationState = navigationState
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case nil:
                rootPage
            case .some(.systemGuidelines):
                systemGuidelinesPage
            case .some(.providerModels):
                providerModelsPage
            }
        }
    }

    // MARK: - Sections

    private var rootPage: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.ai".localized,
                description: "settings.post_processing.description".localized
            )

            mainSection
            if postProcessingViewModel.settings.postProcessingEnabled {
                meetingIntelligenceSection
            }
            contextAwarenessSection
        }
    }

    private var mainSection: some View {
        DSGroup("settings.post_processing.title".localized, icon: "brain") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                DSToggleRow(
                    "settings.post_processing.enabled".localized,
                    description: "settings.post_processing.description".localized,
                    isOn: $postProcessingViewModel.settings.postProcessingEnabled
                )

                VStack(alignment: .leading, spacing: 0) {

                    Divider()

                    SettingsDrillDownButtonRow(
                        title: "settings.post_processing.edit_system_prompt".localized,
                        accessibilityHint: "settings.post_processing.system_guidelines.accessibility_hint".localized
                    ) {
                        navigationState.open(.systemGuidelines)
                    }

                    Divider()

                    SettingsDrillDownButtonRow(
                        title: "settings.enhancements.provider_models.title".localized,
                        accessibilityHint: "settings.enhancements.provider_models.drilldown_hint".localized
                    ) {
                        navigationState.open(.providerModels)
                    }

                    Divider()
                }

                providerModelsQuickSummary
            }
        }
    }

    private var contextAwarenessSection: some View {
        DSGroup("settings.context_awareness.title".localized, icon: "text.viewfinder") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                DSToggleRow(
                    "settings.context_awareness.enabled".localized,
                    description: "settings.context_awareness.enabled_desc".localized,
                    isOn: $postProcessingViewModel.settings.contextAwarenessEnabled
                )

                if postProcessingViewModel.settings.contextAwarenessEnabled {
                    DSToggleRow(
                        "settings.context_awareness.explicit_action_only".localized,
                        description: "settings.context_awareness.explicit_action_only_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessExplicitActionOnly
                    )

                    DSToggleRow(
                        "settings.context_awareness.accessibility_text".localized,
                        description: "settings.context_awareness.accessibility_text_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeAccessibilityText
                    )

                    if postProcessingViewModel.settings.contextAwarenessIncludeAccessibilityText {
                        contextAwarenessSupportStatus
                    }

                    Divider()

                    DSToggleRow(
                        "settings.context_awareness.clipboard".localized,
                        description: "settings.context_awareness.clipboard_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeClipboard
                    )

                    DSToggleRow(
                        "settings.context_awareness.window_ocr".localized,
                        description: "settings.context_awareness.window_ocr_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeWindowOCR
                    )

                    if postProcessingViewModel.settings.contextAwarenessIncludeWindowOCR {
                        screenRecordingSupportStatus
                    }

                    DSToggleRow(
                        "settings.context_awareness.redact_sensitive_data".localized,
                        description: "settings.context_awareness.redact_sensitive_data_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessRedactSensitiveData
                    )

                    Divider()

                    DSToggleRow(
                        "settings.context_awareness.protect_sensitive_apps".localized,
                        description: "settings.context_awareness.protect_sensitive_apps_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessProtectSensitiveApps
                    )

                    if postProcessingViewModel.settings.contextAwarenessProtectSensitiveApps {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsTitleWithPopover(
                                title: "settings.context_awareness.excluded_apps".localized,
                                helperMessage: "settings.context_awareness.excluded_apps_desc".localized,
                                font: .subheadline,
                                fontWeight: .medium
                            )

                            TextEditor(text: excludedBundleIDsBinding)
                                .font(.caption.monospaced())
                                .frame(minHeight: 72)
                                .enhancementsEditorSurface(intensity: .subtle)

                            SettingsTitleWithPopover(
                                title: "settings.context_awareness.base_exclusions".localized,
                                helperMessage: "settings.context_awareness.base_exclusions_desc".localized,
                                font: .caption,
                                fontWeight: .medium
                            )

                            Text(TextContextExclusionPolicy.defaultBundleIDs.joined(separator: "\n"))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var contextAwarenessSupportStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch supportStatus {
            case .permissionDenied:
                DSCallout(
                    kind: .warning,
                    title: "settings.context_awareness.permission_title".localized,
                    message: "settings.context_awareness.permission_desc".localized
                )

                HStack(spacing: 8) {
                    Button("permissions.request".localized) {
                        AccessibilityPermissionService.requestPermission()
                        Task { await refreshSupportStatus() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button("permissions.configure".localized) {
                        AccessibilityPermissionService.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

            case .noActiveApp, .supported, .unknown, .noFocusedElement, .unsupported:
                EmptyView()
            }
        }
        .task { await refreshSupportStatus() }
    }

    private var screenRecordingSupportStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hasScreenRecordingPermission {
                DSCallout(
                    kind: .warning,
                    title: "settings.context_awareness.screen_permission_title".localized,
                    message: "settings.context_awareness.screen_permission_desc".localized
                )

                HStack(spacing: 8) {
                    Button("permissions.request".localized) {
                        CGRequestScreenCaptureAccess()
                        refreshScreenRecordingPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button("permissions.configure".localized) {
                        openScreenRecordingSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .task { refreshScreenRecordingPermission() }
    }

    private var meetingIntelligenceSection: some View {
        DSGroup("settings.enhancements.meeting_intelligence_model".localized, icon: "bubble.left.and.bubble.right.fill") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                DSToggleRow(
                    "transcription.qa.title".localized,
                    description: "settings.enhancements.qa_enabled_desc".localized,
                    isOn: $postProcessingViewModel.settings.meetingQnAEnabled
                )

                if !postProcessingViewModel.settings.isEnhancementsInferenceReady {
                    Divider()
                    DSCallout(
                        kind: .info,
                        title: "settings.enhancements.selector.moved_title".localized,
                        message: "settings.enhancements.selector.moved_message".localized
                    )
                }
            }
        }
    }

    private var providerModelsPage: some View {
        EnhancementsProviderModelsPage(
            viewModel: viewModel,
            postProcessingViewModel: postProcessingViewModel
        )
    }

    private var systemGuidelinesPage: some View {
        SettingsScrollableContent {
            DSGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SettingsTitleWithPopover(
                            title: "settings.post_processing.base_instructions".localized,
                            helperMessage: "prompt.instructions_hint".localized,
                            font: .subheadline,
                            fontWeight: .medium
                        )
                        Spacer()
                        Button("settings.post_processing.restore_default".localized) {
                            restoreSystemGuidelines()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    TextEditor(text: $systemGuidelinesDraft)
                        .font(.body)
                        .frame(minHeight: 250)
                        .enhancementsEditorSurface(intensity: .strong)

                    HStack {
                        Spacer()
                        Button("common.save".localized) {
                            saveSystemGuidelines()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppDesignSystem.Colors.accent)
                        .disabled(systemGuidelinesDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            systemGuidelinesDraft = postProcessingViewModel.settings.systemPrompt
        }
    }

    private var excludedBundleIDsBinding: Binding<String> {
        Binding(
            get: {
                postProcessingViewModel.settings.contextAwarenessExcludedBundleIDs.joined(separator: "\n")
            },
            set: { newValue in
                postProcessingViewModel.settings.contextAwarenessExcludedBundleIDs = parseBundleIDs(from: newValue)
            }
        )
    }

    private var providerModelsQuickSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            modelSummaryRow(
                title: "settings.enhancements.selector.meeting.title".localized,
                summary: selectionSummary(for: postProcessingViewModel.settings.enhancementsAISelection)
            )
            modelSummaryRow(
                title: "settings.enhancements.selector.dictation.title".localized,
                summary: selectionSummary(for: postProcessingViewModel.settings.enhancementsDictationAISelection)
            )
        }
    }

    private func modelSummaryRow(title: String, summary: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(summary)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
    }

    private func selectionSummary(for selection: EnhancementsAISelection) -> String {
        let selectedModel = selection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            return "settings.enhancements.provider_models.summary.no_model".localized(with: selection.provider.displayName)
        }
        return "settings.enhancements.provider_models.summary".localized(with: selection.provider.displayName, selectedModel)
    }

    private func restoreSystemGuidelines() {
        postProcessingViewModel.resetSystemPrompt()
        systemGuidelinesDraft = postProcessingViewModel.settings.systemPrompt
    }

    private func saveSystemGuidelines() {
        postProcessingViewModel.handleSaveSystemPrompt(systemGuidelinesDraft)
    }

    private func parseBundleIDs(from rawValue: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for token in rawValue
            .replacingOccurrences(of: ",", with: "\n")
            .components(separatedBy: .newlines)
        {
            let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            ordered.append(normalized)
        }

        return ordered
    }

    @MainActor
    private func refreshSupportStatus() async {
        supportStatus = await supportChecker.checkSupport()
    }

    private func refreshScreenRecordingPermission() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private extension View {
    func enhancementsEditorSurface(
        intensity: AppDesignSystem.SettingsSurfaceIntensity = .subtle
    ) -> some View {
        padding(AppDesignSystem.Layout.textAreaPadding)
            .background(AppDesignSystem.Colors.settingsInlineBackground(intensity: intensity))
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
    }
}

#Preview {
    EnhancementsSettingsTab()
}
