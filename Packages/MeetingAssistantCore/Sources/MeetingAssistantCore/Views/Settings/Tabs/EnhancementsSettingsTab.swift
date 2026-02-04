import os.log
import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct EnhancementsSettingsTab: View {
    @StateObject private var viewModel = AISettingsViewModel(settings: .shared)
    @StateObject private var postProcessingViewModel = PostProcessingSettingsViewModel()
    @ObservedObject private var modelManager = FluidAIModelManager.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                mainSection

                if postProcessingViewModel.settings.postProcessingEnabled {
                    aiProviderIntegrationCard
                    postProcessingSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $postProcessingViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: postProcessingViewModel.editingPrompt,
                onSave: postProcessingViewModel.handleSavePrompt,
                onCancel: { postProcessingViewModel.showPromptEditor = false }
            )
        }
        .sheet(isPresented: $postProcessingViewModel.showSystemPromptEditor) {
            SystemPromptEditorSheet(
                initialPrompt: postProcessingViewModel.settings.systemPrompt,
                onSave: postProcessingViewModel.handleSaveSystemPrompt,
                onCancel: { postProcessingViewModel.showSystemPromptEditor = false },
                onRestoreDefault: { postProcessingViewModel.resetSystemPrompt() }
            )
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $postProcessingViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                postProcessingViewModel.executeDelete()
            }
        } message: {
            if let prompt = postProcessingViewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
    }

    // MARK: - Sections

    private var mainSection: some View {
        SettingsGroup("settings.general.title".localized, icon: "brain") {
            SettingsToggle(
                "settings.post_processing.enabled".localized,
                description: "settings.post_processing.description".localized,
                isOn: $postProcessingViewModel.settings.postProcessingEnabled
            )

            Divider()
                .padding(.vertical, 4)

            SettingsToggle(
                "settings.ai.diarization".localized,
                description: "settings.ai.diarization_desc".localized,
                isOn: $viewModel.settings.isDiarizationEnabled
            )

            if viewModel.settings.isDiarizationEnabled {
                modelStatusSection

                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 12) {
                    HStack {
                        Text("settings.ai.num_speakers".localized)

                        Spacer()

                        if let num = viewModel.settings.numSpeakers {
                            Stepper(
                                value: Binding(
                                    get: { num },
                                    set: { viewModel.settings.numSpeakers = $0 }
                                ),
                                in: 1...20
                            ) {
                                Text("\(num)")
                                    .fontWeight(.medium)
                                    .frame(width: 24)
                            }
                        } else {
                            Text("settings.ai.speakers_auto".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.settings.numSpeakers != nil },
                                set: { isOn in
                                    viewModel.settings.numSpeakers = isOn ? 2 : nil
                                    if isOn {
                                        viewModel.settings.minSpeakers = nil
                                        viewModel.settings.maxSpeakers = nil
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    if viewModel.settings.numSpeakers == nil {
                        HStack {
                            Text("settings.ai.min_speakers".localized)

                            Spacer()

                            if let min = viewModel.settings.minSpeakers {
                                Stepper(
                                    value: Binding(
                                        get: { min },
                                        set: { viewModel.settings.minSpeakers = $0 }
                                    ),
                                    in: 1...(viewModel.settings.maxSpeakers ?? 20)
                                ) {
                                    Text("\(min)")
                                        .fontWeight(.medium)
                                        .frame(width: 24)
                                }
                            } else {
                                Text("settings.ai.speakers_auto".localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { viewModel.settings.minSpeakers != nil },
                                    set: { isOn in
                                        viewModel.settings.minSpeakers = isOn ? 1 : nil
                                    }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }

                        HStack {
                            Text("settings.ai.max_speakers".localized)

                            Spacer()

                            if let max = viewModel.settings.maxSpeakers {
                                Stepper(
                                    value: Binding(
                                        get: { max },
                                        set: { viewModel.settings.maxSpeakers = $0 }
                                    ),
                                    in: (viewModel.settings.minSpeakers ?? 1)...20
                                ) {
                                    Text("\(max)")
                                        .fontWeight(.medium)
                                        .frame(width: 24)
                                }
                            } else {
                                Text("settings.ai.speakers_auto".localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { viewModel.settings.maxSpeakers != nil },
                                    set: { isOn in
                                        viewModel.settings.maxSpeakers = isOn ? 10 : nil
                                    }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Model Status Section

    @ViewBuilder
    private var modelStatusSection: some View {
        let phase = modelManager.downloadPhase

        // Only show when there's activity or an error
        if phase.isInProgress || phase == .ready || modelManager.lastError != nil {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.itemSpacing) {
                HStack(spacing: 12) {
                    // Phase icon
                    phaseIcon(for: phase)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.localizedDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if phase.isInProgress {
                            Text("settings.ai.please_wait".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if phase.isInProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else if case .failed = phase {
                        Button {
                            Task {
                                await modelManager.retryFailedModels()
                            }
                        } label: {
                            Text("settings.ai.retry".localized)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if phase == .ready {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("settings.ai.ready".localized)
                    }
                }
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.2), value: phase)
        }
    }

    @ViewBuilder
    private func phaseIcon(for phase: FluidAIModelManager.DownloadPhase) -> some View {
        switch phase {
        case .idle:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.secondary)
                .accessibilityLabel("settings.ai.phase_idle".localized)
        case .downloadingASR, .downloadingDiarization:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
                .accessibilityLabel("settings.ai.downloading".localized)
        case .loadingASR, .loadingDiarization:
            Image(systemName: "gearshape.circle.fill")
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
                .accessibilityLabel("settings.ai.loading".localized)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("settings.ai.ready".localized)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("settings.ai.failed".localized)
        }
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
            userPromptsSection
        } else {
            connectionWarningSection
        }
    }

    private var connectionWarningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("settings.post_processing.warning_title".localized)
                    .font(.headline)

                Text("settings.post_processing.warning_desc".localized)
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
        SettingsGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.itemSpacing) {
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

    private var userPromptsSection: some View {
        SettingsGroup("settings.post_processing.prompts".localized, icon: "sparkles") {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.cardPadding) {
                HStack {
                    Text("settings.post_processing.choose_active".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        postProcessingViewModel.editingPrompt = nil
                        postProcessingViewModel.showPromptEditor = true
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
                    ForEach(postProcessingViewModel.settings.allPrompts) { prompt in
                        promptRow(prompt: prompt)
                    }
                }
            }
        }
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = postProcessingViewModel.settings.selectedPromptId == prompt.id

        return Button {
            postProcessingViewModel.selectPrompt(prompt.id)
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
            postProcessingViewModel.selectPrompt(prompt.id, forceSelect: true)
        } label: {
            Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
        }

        Divider()

        Button {
            if prompt.isPredefined {
                postProcessingViewModel.prepareCopy(of: prompt, asDuplicate: false)
            } else {
                postProcessingViewModel.editingPrompt = prompt
                postProcessingViewModel.showPromptEditor = true
            }
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            postProcessingViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            postProcessingViewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
        }
    }
}

#Preview {
    EnhancementsSettingsTab()
}

#Preview {
    EnhancementsSettingsTab()
}
