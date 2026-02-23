import AppKit
import CoreGraphics
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct EnhancementsSettingsTab: View {
    private enum EnhancementsPageRoute: Hashable {
        case systemGuidelines
        case providerModels
    }

    @StateObject private var viewModel: AISettingsViewModel
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel
    @State private var supportStatus: TextContextSupportStatus = .unknown
    @State private var hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    @State private var systemGuidelinesDraft = ""
    private let supportChecker = TextContextSupportChecker()

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
    }

    public var body: some View {
        NavigationStack {
            SettingsScrollableContent {
                SettingsSectionHeader(
                    title: "settings.section.ai".localized,
                    description: "settings.post_processing.description".localized
                )

                mainSection
                if postProcessingViewModel.settings.postProcessingEnabled {
                    meetingIntelligenceSection
                    postProcessingSection
                }
                contextAwarenessSection
            }
            .navigationDestination(for: EnhancementsPageRoute.self) { route in
                switch route {
                case .systemGuidelines:
                    systemGuidelinesPage
                case .providerModels:
                    providerModelsPage
                }
            }
        }
    }

    // MARK: - Sections

    private var mainSection: some View {
        MAGroup("settings.section.ai".localized, icon: "brain") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.itemSpacing) {
                MAToggleRow(
                    "settings.post_processing.enabled".localized,
                    description: "settings.post_processing.description".localized,
                    isOn: $postProcessingViewModel.settings.postProcessingEnabled
                )

                Divider()

                SettingsDrillDownListRow(
                    destination: EnhancementsPageRoute.providerModels,
                    title: "settings.enhancements.provider_models.title".localized,
                    accessibilityHint: "settings.enhancements.provider_models.drilldown_hint".localized
                )

                Divider()

                providerModelsQuickSummary
            }
        }
    }

    private var contextAwarenessSection: some View {
        MAGroup("settings.context_awareness.title".localized, icon: "text.viewfinder") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.itemSpacing) {
                MAToggleRow(
                    "settings.context_awareness.enabled".localized,
                    description: "settings.context_awareness.enabled_desc".localized,
                    isOn: $postProcessingViewModel.settings.contextAwarenessEnabled
                )

                if postProcessingViewModel.settings.contextAwarenessEnabled {
                    MAToggleRow(
                        "settings.context_awareness.explicit_action_only".localized,
                        description: "settings.context_awareness.explicit_action_only_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessExplicitActionOnly
                    )

                    MAToggleRow(
                        "settings.context_awareness.accessibility_text".localized,
                        description: "settings.context_awareness.accessibility_text_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeAccessibilityText
                    )

                    if postProcessingViewModel.settings.contextAwarenessIncludeAccessibilityText {
                        contextAwarenessSupportStatus
                    }

                    Divider()

                    MAToggleRow(
                        "settings.context_awareness.clipboard".localized,
                        description: "settings.context_awareness.clipboard_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeClipboard
                    )

                    MAToggleRow(
                        "settings.context_awareness.window_ocr".localized,
                        description: "settings.context_awareness.window_ocr_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeWindowOCR
                    )

                    if postProcessingViewModel.settings.contextAwarenessIncludeWindowOCR {
                        screenRecordingSupportStatus
                    }

                    MAToggleRow(
                        "settings.context_awareness.redact_sensitive_data".localized,
                        description: "settings.context_awareness.redact_sensitive_data_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessRedactSensitiveData
                    )

                    Divider()

                    MAToggleRow(
                        "settings.context_awareness.protect_sensitive_apps".localized,
                        description: "settings.context_awareness.protect_sensitive_apps_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessProtectSensitiveApps
                    )

                    if postProcessingViewModel.settings.contextAwarenessProtectSensitiveApps {
                        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            Text("settings.context_awareness.excluded_apps".localized)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("settings.context_awareness.excluded_apps_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextEditor(text: excludedBundleIDsBinding)
                                .font(.caption.monospaced())
                                .frame(minHeight: 72)
                                .padding(MeetingAssistantDesignSystem.Layout.textAreaPadding)
                                .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                                .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))

                            Text("settings.context_awareness.base_exclusions".localized)
                                .font(.caption)
                                .fontWeight(.medium)

                            Text("settings.context_awareness.base_exclusions_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(TextContextExclusionPolicy.defaultBundleIDs.joined(separator: "\n"))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, MeetingAssistantDesignSystem.Layout.spacing4)
                    }
                }
            }
        }
    }

    private var contextAwarenessSupportStatus: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            switch supportStatus {
            case .permissionDenied:
                MACallout(
                    kind: .warning,
                    title: "settings.context_awareness.permission_title".localized,
                    message: "settings.context_awareness.permission_desc".localized
                )

                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
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
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            if !hasScreenRecordingPermission {
                MACallout(
                    kind: .warning,
                    title: "settings.context_awareness.screen_permission_title".localized,
                    message: "settings.context_awareness.screen_permission_desc".localized
                )

                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
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
        MAGroup("settings.enhancements.meeting_intelligence_model".localized, icon: "bubble.left.and.bubble.right.fill") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.itemSpacing) {
                MAToggleRow(
                    "transcription.qa.title".localized,
                    description: "settings.enhancements.qa_enabled_desc".localized,
                    isOn: $postProcessingViewModel.settings.meetingQnAEnabled
                )

                if !postProcessingViewModel.settings.isEnhancementsInferenceReady {
                    Divider()
                    MACallout(
                        kind: .info,
                        title: "settings.enhancements.selector.moved_title".localized,
                        message: "settings.enhancements.selector.moved_message".localized
                    )
                }
            }
        }
    }

    // MARK: - Post-Processing

    @ViewBuilder
    private var postProcessingSection: some View {
        if postProcessingViewModel.settings.isEnhancementsInferenceReady {
            systemPromptSection
        } else {
            connectionWarningSection
        }
    }

    private var connectionWarningSection: some View {
        MACallout(
            kind: .warning,
            title: "settings.post_processing.warning_title".localized,
            message: "settings.enhancements.model_warning_desc".localized
        )
    }

    private var providerModelsPage: some View {
        EnhancementsProviderModelsPage(
            viewModel: viewModel,
            postProcessingViewModel: postProcessingViewModel
        )
    }

    private var systemPromptSection: some View {
        MAGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.post_processing.base_instructions".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(postProcessingViewModel.settings.systemPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Divider()

                SettingsDrillDownListRow(
                    destination: EnhancementsPageRoute.systemGuidelines,
                    title: "settings.post_processing.edit_system_guidelines".localized,
                    subtitle: systemGuidelinesSummary,
                    accessibilityHint: "settings.post_processing.system_guidelines.accessibility_hint".localized
                )
            }
        }
    }

    private var systemGuidelinesPage: some View {
        SettingsScrollableContent {
            MAGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    HStack {
                        Text("settings.post_processing.base_instructions".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button("settings.post_processing.restore_default".localized) {
                            restoreSystemGuidelines()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Text("prompt.instructions_hint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $systemGuidelinesDraft)
                        .font(.body)
                        .frame(minHeight: 250)
                        .padding(MeetingAssistantDesignSystem.Layout.textAreaPadding)
                        .background(MeetingAssistantDesignSystem.Colors.textBackground)
                        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                                .stroke(MeetingAssistantDesignSystem.Colors.separator, lineWidth: 1)
                        )

                    HStack {
                        Spacer()
                        Button("common.save".localized) {
                            saveSystemGuidelines()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MeetingAssistantDesignSystem.Colors.accent)
                        .disabled(systemGuidelinesDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .navigationTitle("settings.post_processing.system_prompt_editor_title".localized)
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
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
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
        HStack(alignment: .firstTextBaseline, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: MeetingAssistantDesignSystem.Layout.spacing8)
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

    private var systemGuidelinesSummary: String {
        let isDefault = postProcessingViewModel.settings.systemPrompt == AIPromptTemplates.defaultSystemPrompt
        return isDefault
            ? "settings.post_processing.system_guidelines.default_summary".localized
            : "settings.post_processing.system_guidelines.custom_summary".localized
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

#Preview {
    EnhancementsSettingsTab()
}
