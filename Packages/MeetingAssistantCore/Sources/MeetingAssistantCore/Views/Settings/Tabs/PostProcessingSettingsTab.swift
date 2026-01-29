import SwiftUI

// MARK: - Post-Processing Settings Tab

/// Settings tab for configuring AI post-processing prompts.
public struct PostProcessingSettingsTab: View {
    @StateObject private var viewModel = PostProcessingSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                enableToggleSection

                if viewModel.settings.postProcessingEnabled {
                    if viewModel.settings.aiConfiguration.isValid {
                        systemPromptSection
                        userPromptsSection
                    } else {
                        connectionWarningSection
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $viewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: viewModel.editingPrompt,
                onSave: viewModel.handleSavePrompt,
                onCancel: { viewModel.showPromptEditor = false }
            )
        }
        .sheet(isPresented: $viewModel.showSystemPromptEditor) {
            SystemPromptEditorSheet(
                initialPrompt: viewModel.settings.systemPrompt,
                onSave: viewModel.handleSaveSystemPrompt,
                onCancel: { viewModel.showSystemPromptEditor = false },
                onRestoreDefault: { viewModel.resetSystemPrompt() }
            )
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $viewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                viewModel.executeDelete()
            }
        } message: {
            if let prompt = viewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
    }

    // MARK: - Sections

    private var enableToggleSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    NSLocalizedString("settings.post_processing.enabled", bundle: .safeModule, comment: ""),
                    isOn: $viewModel.settings.postProcessingEnabled
                )
                .font(.headline)
                .toggleStyle(.switch)

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.post_processing.base_instructions", bundle: .safeModule, comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(viewModel.settings.systemPrompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        viewModel.showSystemPromptEditor = true
                    } label: {
                        Label(
                            NSLocalizedString("settings.post_processing.edit_system_guidelines", bundle: .safeModule, comment: ""),
                            systemImage: "pencil"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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
                        viewModel.editingPrompt = nil
                        viewModel.showPromptEditor = true
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
                    ForEach(viewModel.settings.allPrompts) { prompt in
                        promptRow(prompt: prompt)
                    }
                }
            }
        }
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = viewModel.settings.selectedPromptId == prompt.id

        return Button {
            viewModel.selectPrompt(prompt.id)
        } label: {
            HStack(spacing: 12) {
                promptIcon(prompt: prompt, isSelected: isSelected)
                promptInfo(prompt: prompt, isSelected: isSelected)

                Spacer()

                if isSelected {
                    selectionIndicator(isSelected: isSelected)
                }

                promptMenu(prompt: prompt, isSelected: isSelected)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            promptMenuContent(prompt: prompt, isSelected: isSelected)
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

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .symbolEffect(.bounce, value: isSelected)
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
        // Prevent click on menu from triggering the row button
        .highPriorityGesture(TapGesture())
    }

    @ViewBuilder
    private func promptMenuContent(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        Button {
            viewModel.selectPrompt(prompt.id, forceSelect: true)
        } label: {
            Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
        }

        Divider()

        Button {
            if prompt.isPredefined {
                viewModel.prepareCopy(of: prompt, asDuplicate: false)
            } else {
                viewModel.editingPrompt = prompt
                viewModel.showPromptEditor = true
            }
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            viewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
        }
    }
}

#Preview {
    PostProcessingSettingsTab()
}
