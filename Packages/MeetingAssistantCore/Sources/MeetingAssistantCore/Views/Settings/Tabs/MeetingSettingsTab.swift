import KeyboardShortcuts
import SwiftUI

// MARK: - Meeting Settings Tab

/// Tab for meeting-specific settings like app monitoring and automation.
public struct MeetingSettingsTab: View {
    @StateObject private var meetingViewModel = MeetingSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                // Speaker Identification Section
                SettingsGroup("settings.meetings.speaker_identification".localized, icon: "person.wave.2.fill") {
                    SpeakerIdentificationSettingsSection(settings: meetingViewModel.settings)
                }

                // Summary Export Section
                SettingsGroup("settings.meetings.export".localized, icon: "folder.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.meetings.auto_export".localized,
                            description: "settings.meetings.auto_export_desc".localized,
                            isOn: $meetingViewModel.settings.autoExportSummaries
                        )

                        if meetingViewModel.settings.autoExportSummaries {
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

                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(SettingsDesignSystem.Colors.iconHighlight)
                                Text("settings.meetings.template".localized)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            Text("settings.meetings.template_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextEditor(text: $meetingViewModel.settings.summaryTemplate)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 150)
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }

                // Meeting Prompts Section
                SettingsGroup("settings.meetings.prompts".localized, icon: "sparkles") {
                    VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.cardPadding) {
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
                            .controlSize(.small)
                        }

                        VStack(spacing: 8) {
                            ForEach(meetingViewModel.availablePrompts) { prompt in
                                promptRow(prompt: prompt)
                            }
                        }
                    }
                }

                // Automation (Existing)
                SettingsGroup("settings.meetings.workflow".localized, icon: "bolt.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.auto_start".localized,
                            isOn: $meetingViewModel.settings.autoStartRecording
                        )

                        Divider()

                        SettingsToggle(
                            "settings.general.merge_audio".localized,
                            isOn: $meetingViewModel.settings.shouldMergeAudioFiles
                        )
                    }
                }

                // Keyboard Shortcut (Existing)
                SettingsGroup("settings.shortcuts.meeting".localized, icon: "keyboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.shortcuts.meeting_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.shortcuts.meeting".localized)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Picker("", selection: $meetingViewModel.settings.meetingSelectedPresetKey) {
                                ForEach(PresetShortcutKey.allCases, id: \.self) { key in
                                    if let icon = key.icon {
                                        Label(key.displayName, systemImage: icon).tag(key)
                                    } else {
                                        Text(key.displayName).tag(key)
                                    }
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }

                        if meetingViewModel.settings.meetingSelectedPresetKey == .custom {
                            Divider()

                            HStack {
                                Text("settings.shortcuts.custom_shortcut".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                KeyboardShortcuts.Recorder(for: .meetingToggle)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Apps (Existing)
                SettingsGroup("settings.general.monitored_apps".localized, icon: "app.badge") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.general.monitored_apps_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        ForEach(MeetingApp.allCases, id: \.self) { app in
                            HStack(spacing: 12) {
                                Image(systemName: app.icon)
                                    .font(.title3)
                                    .foregroundStyle(app.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("settings.general.monitoring_active".localized)
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }

                                Spacer()
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $meetingViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: meetingViewModel.editingPrompt,
                onSave: meetingViewModel.handleSavePrompt,
                onCancel: { meetingViewModel.showPromptEditor = false }
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
    }
    
    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = meetingViewModel.selectedPromptId == prompt.id

        return Button {
            meetingViewModel.selectPrompt(prompt.id)
        } label: {
            HStack(spacing: 12) {
                promptIcon(prompt: prompt, isSelected: isSelected)
                promptInfo(prompt: prompt, isSelected: isSelected)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: isSelected)
                }

                promptMenu(prompt: prompt, isSelected: isSelected)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
            promptMenuContent(prompt: prompt, isSelected: isSelected)
        }
    }

    private func promptIcon(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? SettingsDesignSystem.Colors.accent : Color.primary.opacity(0.05))
                .frame(width: 36, height: 36)

            Image(systemName: prompt.icon)
                .font(.subheadline)
                .foregroundStyle(isSelected ? SettingsDesignSystem.Colors.onAccent : .primary)
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

    private func promptMenu(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        Menu {
            promptMenuContent(prompt: prompt, isSelected: isSelected)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .highPriorityGesture(TapGesture())
    }

    @ViewBuilder
    private func promptMenuContent(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        Button {
            meetingViewModel.selectPrompt(prompt.id, forceSelect: true)
        } label: {
            Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
        }

        Divider()

        Button {
            if prompt.isPredefined {
                meetingViewModel.prepareCopy(of: prompt, asDuplicate: false)
            } else {
                meetingViewModel.editingPrompt = prompt
                meetingViewModel.showPromptEditor = true
            }
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            meetingViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        if !prompt.isPredefined {
            Divider()

            Button(role: .destructive) {
                meetingViewModel.confirmDeletePrompt(prompt)
            } label: {
                Label("settings.post_processing.delete".localized, systemImage: "trash")
            }
        }
    }
}

#Preview {
    MeetingSettingsTab()
}
