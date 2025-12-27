import SwiftUI

// MARK: - Post-Processing Settings Tab

/// Settings tab for configuring AI post-processing prompts.
public struct PostProcessingSettingsTab: View {
    @StateObject private var viewModel = PostProcessingSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.enableToggleSection

                if self.viewModel.settings.postProcessingEnabled {
                    if self.viewModel.settings.aiConfiguration.isValid {
                        self.systemPromptSection
                        self.userPromptsSection
                    } else {
                        self.connectionWarningSection
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: self.$viewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: self.viewModel.editingPrompt,
                onSave: self.viewModel.handleSavePrompt,
                onCancel: { self.viewModel.showPromptEditor = false }
            )
        }
        .alert(NSLocalizedString("settings.post_processing.delete_confirm_title", bundle: .safeModule, comment: ""), isPresented: self.$viewModel.showDeleteConfirmation) {
            Button(NSLocalizedString("common.cancel", bundle: .safeModule, comment: ""), role: .cancel) {}
            Button(NSLocalizedString("common.delete", bundle: .safeModule, comment: ""), role: .destructive) {
                self.viewModel.executeDelete()
            }
        } message: {
            if let prompt = self.viewModel.promptToDelete {
                Text(String(format: NSLocalizedString("settings.post_processing.delete_confirm_message", bundle: .safeModule, comment: ""), prompt.title))
            }
        }
    }

    // MARK: - Sections

    private var enableToggleSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    NSLocalizedString("settings.post_processing.enabled", bundle: .safeModule, comment: ""),
                    isOn: self.$viewModel.settings.postProcessingEnabled
                )
                .font(.headline)

                Text(NSLocalizedString("settings.post_processing.description", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionWarningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("settings.post_processing.warning_title", bundle: .safeModule, comment: ""))
                    .font(.headline)

                Text(NSLocalizedString("settings.post_processing.warning_desc", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }

    private var systemPromptSection: some View {
        SettingsGroup(NSLocalizedString("settings.post_processing.system_prompt", bundle: .safeModule, comment: ""), icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(NSLocalizedString("settings.post_processing.base_instructions", bundle: .safeModule, comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Button(NSLocalizedString("settings.post_processing.restore_default", bundle: .safeModule, comment: "")) {
                        self.viewModel.resetSystemPrompt()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                TextEditor(text: self.$viewModel.settings.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var userPromptsSection: some View {
        SettingsGroup(NSLocalizedString("settings.post_processing.prompts", bundle: .safeModule, comment: ""), icon: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(NSLocalizedString("settings.post_processing.choose_active", bundle: .safeModule, comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        self.viewModel.editingPrompt = nil
                        self.viewModel.showPromptEditor = true
                    } label: {
                        Label(
                            NSLocalizedString("settings.post_processing.new_prompt", bundle: .safeModule, comment: ""),
                            systemImage: "plus"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                VStack(spacing: 8) {
                    ForEach(PostProcessingPrompt.allPredefined) { prompt in
                        self.promptRow(prompt: prompt, isPredefined: true)
                    }

                    if !self.viewModel.settings.userPrompts.isEmpty {
                        Divider().padding(.vertical, 8)

                        ForEach(self.viewModel.settings.userPrompts) { prompt in
                            self.promptRow(prompt: prompt, isPredefined: false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt, isPredefined: Bool) -> some View {
        let isSelected = self.viewModel.settings.selectedPromptId == prompt.id

        return HStack(spacing: 12) {
            self.promptIcon(prompt: prompt, isSelected: isSelected)
            self.promptInfo(prompt: prompt, isSelected: isSelected)

            Spacer()

            if isSelected {
                self.selectionIndicator
            }

            if !isPredefined {
                self.promptMenu(prompt: prompt)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            self.viewModel.selectPrompt(prompt.id)
        }
    }

    private func promptIcon(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                .frame(width: 36, height: 36)

            Image(systemName: prompt.icon)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
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

    private var selectionIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .symbolEffect(.bounce, value: true)
    }

    private func promptMenu(prompt: PostProcessingPrompt) -> some View {
        Menu {
            Button {
                self.viewModel.editingPrompt = prompt
                self.viewModel.showPromptEditor = true
            } label: {
                Label(NSLocalizedString("settings.post_processing.edit", bundle: .safeModule, comment: ""), systemImage: "pencil")
            }

            Button(role: .destructive) {
                self.viewModel.confirmDeletePrompt(prompt)
            } label: {
                Label(NSLocalizedString("settings.post_processing.delete", bundle: .safeModule, comment: ""), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

#Preview {
    PostProcessingSettingsTab()
}
