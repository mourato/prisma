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
    @StateObject private var viewModel = AISettingsViewModel(settings: .shared)
    @StateObject private var postProcessingViewModel = PostProcessingSettingsViewModel()
    @StateObject private var markdownTargetsViewModel: InstalledAppsSelectionViewModel
    @StateObject private var webBrowserTargetsViewModel: InstalledAppsSelectionViewModel
    @StateObject private var markdownWebTargetsViewModel: WebMarkdownTargetsViewModel
    @State private var supportStatus: TextContextSupportStatus = .unknown
    private let supportChecker = TextContextSupportChecker()

    public init(settings: AppSettingsStore = .shared) {
        _markdownTargetsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: AppSettingsStore.defaultMarkdownTargetBundleIdentifiers,
                hasConfigured: { settings.hasConfiguredMarkdownTargets },
                loadBundleIdentifiers: { settings.markdownTargetBundleIdentifiers },
                saveBundleIdentifiers: { settings.markdownTargetBundleIdentifiers = $0 }
            )
        )
        _webBrowserTargetsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: AppSettingsStore.defaultWebTargetBrowserBundleIdentifiers,
                hasConfigured: { settings.hasConfiguredWebTargetBrowsers },
                loadBundleIdentifiers: { settings.webTargetBrowserBundleIdentifiers },
                saveBundleIdentifiers: { settings.webTargetBrowserBundleIdentifiers = $0 }
            )
        )
        _markdownWebTargetsViewModel = StateObject(wrappedValue: WebMarkdownTargetsViewModel(settings: settings))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                mainSection
                if postProcessingViewModel.settings.postProcessingEnabled {
                    aiProviderIntegrationCard
                    postProcessingSection
                }
                contextAwarenessSection
                markdownTargetsSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $postProcessingViewModel.showSystemPromptEditor) {
            SystemPromptEditorSheet(
                initialPrompt: postProcessingViewModel.settings.systemPrompt,
                onSave: postProcessingViewModel.handleSaveSystemPrompt,
                onCancel: { postProcessingViewModel.showSystemPromptEditor = false },
                onRestoreDefault: { postProcessingViewModel.resetSystemPrompt() }
            )
        }
        .sheet(isPresented: $markdownWebTargetsViewModel.showEditor) {
            WebMarkdownTargetEditorSheet(
                target: markdownWebTargetsViewModel.editingTarget,
                onSave: markdownWebTargetsViewModel.handleSave,
                onCancel: { markdownWebTargetsViewModel.showEditor = false }
            )
        }
        .alert(
            "settings.markdown_targets.websites.delete_confirm_title".localized,
            isPresented: $markdownWebTargetsViewModel.showDeleteConfirmation
        ) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                markdownWebTargetsViewModel.executeDelete()
            }
        } message: {
            if let target = markdownWebTargetsViewModel.targetToDelete {
                Text("settings.markdown_targets.websites.delete_confirm_message".localized(with: target.displayName))
            }
        }
    }

    // MARK: - Sections

    private var mainSection: some View {
        MAGroup("settings.general.title".localized, icon: "brain") {
            MAToggleRow(
                "settings.post_processing.enabled".localized,
                description: "settings.post_processing.description".localized,
                isOn: $postProcessingViewModel.settings.postProcessingEnabled
            )
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
                                .padding(6)
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

    private var markdownTargetsSection: some View {
        MAGroup("settings.markdown_targets.title".localized, icon: "textformat") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                InstalledAppsSelectionList(
                    descriptionKey: "settings.markdown_targets.description",
                    emptyKey: "settings.markdown_targets.empty",
                    addButtonKey: "settings.markdown_targets.add",
                    viewModel: markdownTargetsViewModel
                )

                Divider()

                InstalledAppsSelectionList(
                    descriptionKey: "settings.web_targets.browsers.description",
                    emptyKey: "settings.web_targets.browsers.empty",
                    addButtonKey: "settings.web_targets.browsers.add",
                    viewModel: webBrowserTargetsViewModel
                )

                Divider()

                markdownWebTargetsSection
            }
        }
    }

    private var markdownWebTargetsSection: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Text("settings.markdown_targets.websites.title".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("settings.markdown_targets.websites.desc".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            if markdownWebTargetsViewModel.targets.isEmpty {
                Text("settings.markdown_targets.websites.empty".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(markdownWebTargetsViewModel.targets.enumerated()), id: \.element.id) { index, target in
                        markdownWebTargetRow(target)

                        if index < markdownWebTargetsViewModel.targets.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
            }

            HStack {
                Spacer()
                Button {
                    markdownWebTargetsViewModel.addTarget()
                } label: {
                    Label("settings.markdown_targets.websites.add".localized, systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func markdownWebTargetRow(_ target: WebContextTarget) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.iconHighlight)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(target.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(target.urlPatterns.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(browserNames(from: target.browserBundleIdentifiers))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                markdownWebTargetsViewModel.editTarget(target)
            } label: {
                Image(systemName: "pencil")
                    .accessibilityLabel("settings.markdown_targets.websites.edit".localized)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button(role: .destructive) {
                markdownWebTargetsViewModel.confirmDelete(target)
            } label: {
                Image(systemName: "trash")
                    .accessibilityLabel("settings.markdown_targets.websites.delete".localized)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }

    private func browserNames(from bundleIdentifiers: [String]) -> String {
        let fallbackBundleIdentifiers = viewModel.settings.webTargetBrowserBundleIdentifiers

        // If both the target-specific list and the global fallback list are empty,
        // no browsers will actually match. Reflect that in the UI instead of
        // suggesting that any browser is allowed.
        if bundleIdentifiers.isEmpty && fallbackBundleIdentifiers.isEmpty {
            return "settings.web_targets.browsers.empty".localized
        }

        let effectiveBundleIdentifiers = bundleIdentifiers.isEmpty ? fallbackBundleIdentifiers : bundleIdentifiers
        let names = effectiveBundleIdentifiers
            .map { WebTargetEditorSupport.browserDisplayName(for: $0) }
            .sorted()
        let display = names.joined(separator: ", ")
        return "settings.markdown_targets.websites.browsers".localized(with: display)
    }

    @ViewBuilder
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
                    .controlSize(.small)

                    Button("permissions.configure".localized) {
                        AccessibilityPermissionService.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

            case .noActiveApp, .supported, .unknown, .noFocusedElement, .unsupported:
                EmptyView()
            }

            Button("settings.context_awareness.support_status_check".localized) {
                Task { await refreshSupportStatus() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .task { await refreshSupportStatus() }
    }

    // MARK: - AI Provider Integration Card

    private var aiProviderIntegrationCard: some View {
        AIProviderIntegrationCard(viewModel: viewModel)
    }

    // MARK: - Post-Processing

    @ViewBuilder
    private var postProcessingSection: some View {
        if viewModel.settings.aiConfiguration.isValid {
            systemPromptSection
        } else {
            connectionWarningSection
        }
    }

    private var connectionWarningSection: some View {
        MACallout(
            kind: .warning,
            title: "settings.post_processing.warning_title".localized,
            message: "settings.post_processing.warning_desc".localized
        )
    }

    private var systemPromptSection: some View {
        MAGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.itemSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.post_processing.base_instructions".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(postProcessingViewModel.settings.systemPrompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        postProcessingViewModel.showSystemPromptEditor = true
                    } label: {
                        Label(
                            "settings.post_processing.edit_system_guidelines".localized,
                            systemImage: "pencil"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
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
}

#Preview {
    EnhancementsSettingsTab()
}
