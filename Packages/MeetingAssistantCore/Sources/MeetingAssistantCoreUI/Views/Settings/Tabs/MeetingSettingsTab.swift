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

            InstalledAppsSelectionSection(
                titleKey: "settings.general.monitored_apps",
                descriptionKey: "settings.general.monitored_apps_desc",
                emptyKey: "settings.general.monitored_apps_empty",
                addButtonKey: "settings.general.monitored_apps_add",
                icon: "app.badge",
                viewModel: monitoredAppsViewModel
            )

            webTargetsSection
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
        .sheet(isPresented: $webTargetsViewModel.showEditor) {
            WebMeetingTargetEditorSheet(
                target: webTargetsViewModel.editingTarget,
                onSave: webTargetsViewModel.handleSave,
                onCancel: { webTargetsViewModel.showEditor = false }
            )
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

                if webTargetsViewModel.targets.isEmpty {
                    Text("settings.meetings.web_targets.empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(webTargetsViewModel.targets.enumerated()), id: \.element.id) { index, target in
                            webTargetRow(target)

                            if index < webTargetsViewModel.targets.count - 1 {
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
        let fallbackBundleIdentifiers = meetingViewModel.settings.effectiveWebTargetBrowserBundleIdentifiers
        let effectiveBundleIdentifiers = bundleIdentifiers.isEmpty ? fallbackBundleIdentifiers : bundleIdentifiers
        if effectiveBundleIdentifiers.isEmpty {
            return "settings.web_targets.browsers.empty".localized
        }

        let names = effectiveBundleIdentifiers
            .map { WebTargetEditorSupport.browserDisplayName(for: $0) }
            .sorted()

        return "settings.meetings.web_targets.browsers".localized(with: names.joined(separator: ", "))
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isAutoDetectEnabled = meetingViewModel.settings.meetingTypeAutoDetectEnabled
        let isSelected = !isAutoDetectEnabled && meetingViewModel.selectedPromptId == prompt.id

        let row = HStack(spacing: 12) {
            promptIcon(prompt: prompt, isSelected: isSelected)
            promptInfo(prompt: prompt, isSelected: isSelected)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
            }

            promptMenu(prompt: prompt, isSelected: isSelected, isAutoDetectEnabled: isAutoDetectEnabled)
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing10)
        .contentShape(Rectangle())

        return Group {
            if isAutoDetectEnabled {
                row
            } else {
                Button {
                    meetingViewModel.selectPrompt(prompt.id)
                } label: {
                    row
                }
                .buttonStyle(.plain)
            }
        }
        .background(isSelected ? MeetingAssistantDesignSystem.Colors.selectionFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius)
                .stroke(isSelected ? MeetingAssistantDesignSystem.Colors.selectionStroke : MeetingAssistantDesignSystem.Colors.separator.opacity(0.4), lineWidth: 1)
        )
        .contextMenu {
            promptMenuContent(prompt: prompt, isSelected: isSelected, isAutoDetectEnabled: isAutoDetectEnabled)
        }
    }

    private func promptIcon(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                .fill(isSelected ? MeetingAssistantDesignSystem.Colors.accent : MeetingAssistantDesignSystem.Colors.subtleFill)
                .frame(width: 36, height: 36)

            Image(systemName: prompt.icon)
                .font(.subheadline)
                .foregroundStyle(isSelected ? MeetingAssistantDesignSystem.Colors.onAccent : .primary)
        }
    }

    private func promptInfo(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(prompt.title)
                .font(.body)
                .fontWeight(isSelected ? .bold : .medium)

            if let description = prompt.description {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func promptMenu(prompt: PostProcessingPrompt, isSelected: Bool, isAutoDetectEnabled: Bool) -> some View {
        Menu {
            promptMenuContent(prompt: prompt, isSelected: isSelected, isAutoDetectEnabled: isAutoDetectEnabled)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .highPriorityGesture(TapGesture())
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

        let row = HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? SettingsDesignSystem.Colors.accent : Color.primary.opacity(0.05))
                    .frame(width: 36, height: 36)

                Image(systemName: "nosign")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? SettingsDesignSystem.Colors.onAccent : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("recording_indicator.prompt.none".localized)
                    .font(.body)
                    .fontWeight(isSelected ? .bold : .medium)

                Text("recording_indicator.prompt.none_desc".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
                .opacity(0) // Keep layout aligned with prompt rows
        }
        .padding(10)
        .contentShape(Rectangle())

        return Group {
            if isAutoDetectEnabled {
                row
            } else {
                Button {
                    meetingViewModel.selectPrompt(AppSettingsStore.noPostProcessingPromptId, forceSelect: true)
                } label: {
                    row
                }
                .buttonStyle(.plain)
            }
        }
        .background(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    MeetingSettingsTab()
}
