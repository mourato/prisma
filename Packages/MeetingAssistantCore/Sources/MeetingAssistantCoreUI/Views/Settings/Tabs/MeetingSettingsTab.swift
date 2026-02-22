import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Meeting Settings Tab

/// Tab for meeting-specific settings like app monitoring and automation.
public struct MeetingSettingsTab: View {
    @StateObject private var meetingViewModel: MeetingSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var monitoredAppsViewModel: InstalledAppsSelectionViewModel
    @StateObject private var webTargetsViewModel: WebMeetingTargetsViewModel
    @State private var showSummaryTemplateEditor = false
    @State private var showMonitoringTargetsModal = false

    public init(settings: AppSettingsStore = .shared) {
        _meetingViewModel = StateObject(wrappedValue: MeetingSettingsViewModel(settings: settings))
        _monitoredAppsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: AppSettingsStore.defaultMonitoredMeetingBundleIdentifiers,
                hasConfigured: { settings.hasConfiguredMonitoredMeetingApps },
                loadBundleIdentifiers: { settings.monitoredMeetingBundleIdentifiers },
                saveBundleIdentifiers: { settings.monitoredMeetingBundleIdentifiers = $0 }
            )
        )
        _webTargetsViewModel = StateObject(wrappedValue: WebMeetingTargetsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            // Keyboard Shortcut (Existing)
            MAShortcutSettingsSection(
                groupTitle: "settings.shortcuts.meeting".localized,
                descriptionText: "settings.shortcuts.meeting_desc".localized,
                settingsContent: {
                    MAModifierShortcutEditor(
                        shortcut: $shortcutsViewModel.meetingShortcutDefinition,
                        conflictMessage: shortcutsViewModel.meetingModifierConflictMessage
                    )
                }
            )

            MAGroup("settings.meetings.monitoring_access.title".localized, icon: "app.badge") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    Text("settings.meetings.monitoring_access.desc".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Spacer()
                        Button("settings.meetings.monitoring_access.button".localized) {
                            showMonitoringTargetsModal = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }

            // Automation (Existing)
            MAGroup("settings.meetings.workflow".localized, icon: "bolt.fill") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    MAToggleRow(
                        "settings.general.auto_start".localized,
                        isOn: $meetingViewModel.settings.autoStartRecording
                    )

                    Divider()

                    MAToggleRow(
                        "settings.general.merge_audio".localized,
                        isOn: $meetingViewModel.settings.shouldMergeAudioFiles
                    )
                }
            }

            // Speaker Identification Section
            MAGroup("settings.meetings.speaker_identification".localized, icon: "person.wave.2.fill") {
                SpeakerIdentificationSettingsSection(settings: meetingViewModel.settings)
            }

            // Summary Export Section
            MAGroup("settings.meetings.export".localized, icon: "folder.fill") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    MAToggleRow(
                        "settings.meetings.auto_export".localized,
                        description: "settings.meetings.auto_export_desc".localized,
                        isOn: $meetingViewModel.settings.autoExportSummaries
                    )

                    if meetingViewModel.settings.autoExportSummaries {
                        Divider()

                        HStack {
                            Text("settings.meetings.export_location".localized)
                            Spacer()
                            if let url = meetingViewModel.settings.summaryExportFolder {
                                Text(url.lastPathComponent)
                                    .foregroundStyle(.secondary)
                                    .truncationMode(.middle)
                            } else {
                                Text("settings.meetings.no_folder_selected".localized)
                                    .foregroundStyle(.secondary)
                            }
                            Button("common.select".localized) {
                                meetingViewModel.selectExportFolder()
                            }
                        }

                        Text("settings.meetings.export_location_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        MAToggleRow(
                            "settings.meetings.template_enabled".localized,
                            description: "settings.meetings.template_enabled_desc".localized,
                            isOn: $meetingViewModel.settings.summaryTemplateEnabled
                        )

                        Divider()

                        HStack {
                            Text("settings.meetings.export_safety_policy".localized)
                            Spacer()
                            Picker("", selection: $meetingViewModel.settings.summaryExportSafetyPolicyLevel) {
                                ForEach(SummaryExportSafetyPolicyLevel.allCases, id: \.self) { level in
                                    Text(exportSafetyPolicyLabel(level)).tag(level)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        Text("settings.meetings.export_safety_policy_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if meetingViewModel.settings.summaryExportFolder == nil {
                            Text("settings.meetings.export_location_required".localized)
                                .font(.caption)
                                .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
                        }

                        if meetingViewModel.settings.summaryTemplateEnabled {
                            Divider()

                            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.iconHighlight)
                                Text("settings.meetings.template".localized)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            Text("settings.meetings.template_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Spacer()
                                Button {
                                    showSummaryTemplateEditor = true
                                } label: {
                                    Label("settings.meetings.template.edit".localized, systemImage: "pencil")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                    }
                }
            }

            // Meeting Prompts Section
            MAGroup("settings.meetings.prompts".localized, icon: "sparkles") {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.cardPadding) {
                    MAToggleRow(
                        "settings.meetings.autodetect_type".localized,
                        description: "settings.meetings.autodetect_type_desc".localized,
                        isOn: $meetingViewModel.settings.meetingTypeAutoDetectEnabled
                    )

                    HStack {
                        Text("settings.post_processing.choose_active".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            meetingViewModel.editingPrompt = nil
                            meetingViewModel.showPromptEditor = true
                        } label: {
                            Label(
                                "settings.post_processing.new_prompt".localized,
                                systemImage: "plus"
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                        noPostProcessingRow()
                        ForEach(meetingViewModel.availablePrompts) { prompt in
                            promptRow(prompt: prompt)
                        }
                    }
                }
            }

        }
        .sheet(isPresented: $meetingViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: meetingViewModel.editingPrompt,
                onSave: meetingViewModel.handleSavePrompt,
                onCancel: { meetingViewModel.showPromptEditor = false }
            )
        }
        .sheet(isPresented: $showSummaryTemplateEditor) {
            SummaryTemplateEditorSheet(
                initialTemplate: meetingViewModel.settings.summaryTemplate,
                onSave: { updatedTemplate in
                    meetingViewModel.settings.summaryTemplate = updatedTemplate
                    showSummaryTemplateEditor = false
                },
                onCancel: { showSummaryTemplateEditor = false }
            )
        }
        .sheet(isPresented: $showMonitoringTargetsModal) {
            monitoringTargetsSheet
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $meetingViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                meetingViewModel.executeDelete()
            }
        } message: {
            if let prompt = meetingViewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
    }

    private var monitoringTargetsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("settings.meetings.monitoring_access.modal_title".localized)
                    .font(.headline)
                Spacer()
                Button {
                    showMonitoringTargetsModal = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .controlSize(.regular)
            }
            .padding()

            Divider()

            SettingsScrollableContent {
                InstalledAppsSelectionSection(
                    titleKey: "settings.general.monitored_apps",
                    descriptionKey: "settings.general.monitored_apps_desc",
                    emptyKey: "settings.general.monitored_apps_empty",
                    addButtonKey: "settings.general.monitored_apps_add",
                    icon: "app.badge",
                    viewModel: monitoredAppsViewModel
                )

                webTargetsSection

                HStack {
                    Spacer()
                    Button("settings.meetings.monitoring_access.done".localized) {
                        showMonitoringTargetsModal = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(.top, MeetingAssistantDesignSystem.Layout.spacing8)
        }
        .frame(width: 760, height: 560)
        .sheet(isPresented: $webTargetsViewModel.showEditor) {
            WebMeetingTargetEditorSheet(
                target: webTargetsViewModel.editingTarget,
                onSave: webTargetsViewModel.handleSave,
                onCancel: { webTargetsViewModel.showEditor = false }
            )
        }
        .alert("settings.meetings.web_targets.delete_confirm_title".localized, isPresented: $webTargetsViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                webTargetsViewModel.executeDelete()
            }
        } message: {
            if let target = webTargetsViewModel.targetToDelete {
                Text("settings.meetings.web_targets.delete_confirm_message".localized(with: target.displayName))
            }
        }
    }

    private var webTargetsSection: some View {
        MAGroup("settings.meetings.web_targets.title".localized, icon: "globe") {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Text("settings.meetings.web_targets.desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SettingsInlineList(
                    items: webTargetsViewModel.targets,
                    emptyText: "settings.meetings.web_targets.empty".localized
                ) { target in
                    webTargetRow(target)
                }

                HStack {
                    Spacer()
                    Button {
                        webTargetsViewModel.addTarget()
                    } label: {
                        Label("settings.meetings.web_targets.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private func webTargetRow(_ target: WebMeetingTarget) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Image(systemName: target.app.icon)
                .font(.title3)
                .foregroundStyle(target.app.color)
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
                webTargetsViewModel.editTarget(target)
            } label: {
                Image(systemName: "pencil")
                    .accessibilityLabel("settings.meetings.web_targets.edit".localized)
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)

            Button(role: .destructive) {
                webTargetsViewModel.confirmDelete(target)
            } label: {
                Image(systemName: "trash")
                    .accessibilityLabel("settings.meetings.web_targets.delete".localized)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            .controlSize(.regular)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
    }

    private func browserNames(from bundleIdentifiers: [String]) -> String {
        WebTargetBrowserNamesFormatter.formattedNames(
            bundleIdentifiers: bundleIdentifiers,
            fallbackBundleIdentifiers: meetingViewModel.settings.effectiveWebTargetBrowserBundleIdentifiers,
            localizedListKey: "settings.meetings.web_targets.browsers"
        )
    }

    private func exportSafetyPolicyLabel(_ level: SummaryExportSafetyPolicyLevel) -> String {
        switch level {
        case .permissive:
            return "settings.meetings.export_safety_policy.permissive".localized
        case .standard:
            return "settings.meetings.export_safety_policy.standard".localized
        case .strict:
            return "settings.meetings.export_safety_policy.strict".localized
        }
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isAutoDetectEnabled = meetingViewModel.settings.meetingTypeAutoDetectEnabled
        let isSelected = !isAutoDetectEnabled && meetingViewModel.selectedPromptId == prompt.id

        return PromptSelectionRow(
            iconSystemName: prompt.icon,
            title: prompt.title,
            description: prompt.description,
            isSelected: isSelected,
            onSelect: isAutoDetectEnabled ? nil : {
                meetingViewModel.selectPrompt(prompt.id)
            },
            unselectedStrokeColor: MeetingAssistantDesignSystem.Colors.separator.opacity(0.4)
        ) {
            promptMenuContent(prompt: prompt, isSelected: isSelected, isAutoDetectEnabled: isAutoDetectEnabled)
        }
    }

    @ViewBuilder
    private func promptMenuContent(prompt: PostProcessingPrompt, isSelected: Bool, isAutoDetectEnabled: Bool) -> some View {
        if !isAutoDetectEnabled {
            Button {
                meetingViewModel.selectPrompt(prompt.id, forceSelect: true)
            } label: {
                Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
            }

            Divider()
        }

        Button {
            meetingViewModel.editingPrompt = prompt
            meetingViewModel.showPromptEditor = true
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            meetingViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            meetingViewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
        }
    }

    private func noPostProcessingRow() -> some View {
        let isAutoDetectEnabled = meetingViewModel.settings.meetingTypeAutoDetectEnabled
        let isSelected = !isAutoDetectEnabled && meetingViewModel.selectedPromptId == AppSettingsStore.noPostProcessingPromptId

        return PromptSelectionRow(
            iconSystemName: "nosign",
            title: "recording_indicator.prompt.none".localized,
            description: "recording_indicator.prompt.none_desc".localized,
            isSelected: isSelected,
            onSelect: isAutoDetectEnabled ? nil : {
                meetingViewModel.selectPrompt(AppSettingsStore.noPostProcessingPromptId, forceSelect: true)
            },
            unselectedStrokeColor: Color.secondary.opacity(0.1),
            showMenu: false,
            preserveMenuSpacing: true
        ) {
            EmptyView()
        }
    }
}

#Preview {
    MeetingSettingsTab()
}
