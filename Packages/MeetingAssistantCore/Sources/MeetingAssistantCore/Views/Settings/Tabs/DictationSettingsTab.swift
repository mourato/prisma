import KeyboardShortcuts
import SwiftUI

// MARK: - Dictation Settings Tab

/// Tab for dictation-specific settings like auto-copy/paste and shortcuts.
public struct DictationSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var promptViewModel = DictationPromptSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                // Workflow
                SettingsGroup("settings.dictation.workflow".localized, icon: "cpu") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.auto_copy_transcription".localized,
                            description: "settings.general.auto_copy_transcription_desc".localized,
                            isOn: $viewModel.autoCopyTranscriptionToClipboard
                        )

                        Divider()

                        SettingsToggle(
                            "settings.general.auto_paste_transcription".localized,
                            isOn: $viewModel.autoPasteTranscriptionToActiveApp
                        )
                    }
                }

                // Keyboard Shortcut
                SettingsGroup("settings.shortcuts.dictation".localized, icon: "keyboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.shortcuts.dictation_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.shortcuts.dictation".localized)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Picker("", selection: $shortcutsViewModel.dictationSelectedPresetKey) {
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

                        if shortcutsViewModel.dictationSelectedPresetKey == .custom {
                            Divider()

                            HStack {
                                Text("settings.shortcuts.custom_shortcut".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                KeyboardShortcuts.Recorder(for: .dictationToggle)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Sound Feedback
                SettingsGroup("settings.general.sound_feedback".localized, icon: "speaker.wave.2.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.sound_feedback.enabled".localized,
                            description: "settings.general.sound_feedback.enabled_desc".localized,
                            isOn: $viewModel.soundFeedbackEnabled
                        )

                        if viewModel.soundFeedbackEnabled {
                            Divider()

                            soundPickerRow(
                                title: "settings.general.sound_feedback.start_sound".localized,
                                selection: $viewModel.recordingStartSound
                            )

                            Divider()

                            soundPickerRow(
                                title: "settings.general.sound_feedback.stop_sound".localized,
                                selection: $viewModel.recordingStopSound
                            )
                        }
                    }
                }

                // Dictation Prompts Section
                SettingsGroup("settings.dictation.prompts".localized, icon: "sparkles") {
                    VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.cardPadding) {
                        HStack {
                            Text("settings.post_processing.choose_active".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                promptViewModel.editingPrompt = nil
                                promptViewModel.showPromptEditor = true
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
                            noPostProcessingRow()
                            ForEach(promptViewModel.availablePrompts) { prompt in
                                promptRow(prompt: prompt)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $promptViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: promptViewModel.editingPrompt,
                onSave: promptViewModel.handleSavePrompt,
                onCancel: { promptViewModel.showPromptEditor = false }
            )
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $promptViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                promptViewModel.executeDelete()
            }
        } message: {
            if let prompt = promptViewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
    }

    private func soundPickerRow(title: String, selection: Binding<SoundFeedbackSound>) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: selection) {
                ForEach(SoundFeedbackSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)

            Button {
                SoundFeedbackService.shared.preview(selection.wrappedValue)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(selection.wrappedValue == .none)
            .accessibilityLabel("settings.general.sound_feedback.preview".localized)
        }
    }

    // MARK: - Prompts

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = promptViewModel.effectiveSelectedPromptId == prompt.id

        return Button {
            promptViewModel.selectPrompt(prompt.id, forceSelect: true)
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
                .stroke(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
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
            promptViewModel.selectPrompt(prompt.id, forceSelect: true)
        } label: {
            Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
        }

        Divider()

        Button {
            if prompt.isPredefined {
                promptViewModel.prepareCopy(of: prompt, asDuplicate: false)
            } else {
                promptViewModel.editingPrompt = prompt
                promptViewModel.showPromptEditor = true
            }
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            promptViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        if !prompt.isPredefined {
            Divider()

            Button(role: .destructive) {
                promptViewModel.confirmDeletePrompt(prompt)
            } label: {
                Label("settings.post_processing.delete".localized, systemImage: "trash")
            }
        }
    }

    private func noPostProcessingRow() -> some View {
        let isSelected = promptViewModel.effectiveSelectedPromptId == AppSettingsStore.noPostProcessingPromptId

        return Button {
            promptViewModel.selectPrompt(AppSettingsStore.noPostProcessingPromptId, forceSelect: true)
        } label: {
            HStack(spacing: 12) {
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
                        .symbolEffect(.bounce, value: isSelected)
                }

                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
                    .opacity(0) // Keep layout aligned with prompt rows
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? SettingsDesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    DictationSettingsTab()
}
