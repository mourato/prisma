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
    @StateObject private var markdownTargetsViewModel = MarkdownTargetsViewModel()
    @State private var supportStatus: TextContextSupportStatus = .unknown
    private let supportChecker = TextContextSupportChecker()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                mainSection
                contextAwarenessSection
                markdownTargetsSection

                if postProcessingViewModel.settings.postProcessingEnabled {
                    aiProviderIntegrationCard
                    postProcessingSection
                }
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
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.markdown_targets.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if markdownTargetsViewModel.installedApps.isEmpty {
                    Text("settings.markdown_targets.empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(markdownTargetsViewModel.installedApps.enumerated()), id: \.element.id) { index, app in
                            markdownTargetRow(app)

                            if index < markdownTargetsViewModel.installedApps.count - 1 {
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
                        markdownTargetsViewModel.addApp()
                    } label: {
                        Label("settings.markdown_targets.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            markdownTargetsViewModel.refreshTargets()
        }
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

            case .noFocusedElement, .unsupported:
                MACallout(
                    kind: .info,
                    title: "settings.context_awareness.unsupported_title".localized,
                    message: "settings.context_awareness.unsupported_desc".localized
                )

            case .noActiveApp, .supported, .unknown:
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

    private func markdownTargetRow(_ app: MarkdownTargetApp) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Image(nsImage: app.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .padding(6)
                .background(MeetingAssistantDesignSystem.Colors.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                markdownTargetsViewModel.removeApp(bundleIdentifier: app.bundleIdentifier)
            } label: {
                Image(systemName: "minus.circle")
                    .accessibilityLabel("settings.markdown_targets.remove".localized)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
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
