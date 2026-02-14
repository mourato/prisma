import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
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
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                // Keyboard Shortcut
                MAShortcutSettingsSection(
                    groupTitle: "settings.shortcuts.dictation".localized,
                    descriptionText: "settings.shortcuts.dictation_desc".localized,
                    settingsContent: {
                        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                            MAModifierShortcutEditor(
                                shortcut: $shortcutsViewModel.dictationShortcutDefinition,
                                conflictMessage: shortcutsViewModel.dictationModifierConflictMessage
                            )

                            Divider()

                            MAToggleRow(
                                "settings.shortcuts.use_escape".localized,
                                description: "settings.shortcuts.use_escape_desc".localized,
                                isOn: $shortcutsViewModel.useEscapeToCancelRecording
                            )
                        }
                    }
                )

                // Workflow
                MAGroup("settings.dictation.workflow".localized, icon: "cpu") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                        MAToggleRow(
                            "settings.general.auto_copy_transcription".localized,
                            description: "settings.general.auto_copy_transcription_desc".localized,
                            isOn: $viewModel.autoCopyTranscriptionToClipboard
                        )

                        Divider()

                        MAToggleRow(
                            "settings.general.auto_paste_transcription".localized,
                            isOn: $viewModel.autoPasteTranscriptionToActiveApp
                        )
                    }
                }

                // Dictation Prompts Section
                MAGroup("settings.dictation.prompts".localized, icon: "sparkles") {
                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.cardPadding) {
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

                        VStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
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
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
                        .symbolEffect(.bounce, value: isSelected)
                }

                promptMenu(prompt: prompt, isSelected: isSelected)
            }
            .padding(MeetingAssistantDesignSystem.Layout.spacing10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? MeetingAssistantDesignSystem.Colors.selectionFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius)
                .stroke(isSelected ? MeetingAssistantDesignSystem.Colors.selectionStroke : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            promptMenuContent(prompt: prompt, isSelected: isSelected)
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
            promptViewModel.editingPrompt = prompt
            promptViewModel.showPromptEditor = true
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            promptViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            promptViewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
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
