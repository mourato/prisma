import os.log
import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct AISettingsTab: View {
    @StateObject private var viewModel = AISettingsViewModel(settings: .shared)
    @StateObject private var postProcessingViewModel = PostProcessingSettingsViewModel()
    @ObservedObject private var modelManager = FluidAIModelManager.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                mainSection

                if postProcessingViewModel.settings.postProcessingEnabled {
                    providerSection
                    apiConfigurationSection
                    connectionTestSection
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
        SettingsGroup(NSLocalizedString("settings.general.title", bundle: .safeModule, comment: ""), icon: "brain") {
            SettingsToggle(
                NSLocalizedString("settings.post_processing.enabled", bundle: .safeModule, comment: ""),
                description: NSLocalizedString("settings.post_processing.description", bundle: .safeModule, comment: ""),
                isOn: $postProcessingViewModel.settings.postProcessingEnabled
            )

            Divider()
                .padding(.vertical, 4)

            SettingsToggle(
                NSLocalizedString("settings.ai.diarization", bundle: .safeModule, comment: ""),
                description: NSLocalizedString("settings.ai.diarization_desc", bundle: .safeModule, comment: ""),
                isOn: $viewModel.settings.isDiarizationEnabled
            )

            if viewModel.settings.isDiarizationEnabled {
                modelStatusSection

                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("settings.ai.num_speakers", bundle: .safeModule, comment: ""))

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
                            Text(NSLocalizedString("settings.ai.min_speakers", bundle: .safeModule, comment: ""))

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
                            Text(NSLocalizedString("settings.ai.max_speakers", bundle: .safeModule, comment: ""))

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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Phase icon
                    phaseIcon(for: phase)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.localizedDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if phase.isInProgress {
                            Text(NSLocalizedString("settings.ai.please_wait", bundle: .safeModule, comment: ""))
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
                            Text(NSLocalizedString("settings.ai.retry", bundle: .safeModule, comment: ""))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if phase == .ready {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel(NSLocalizedString("settings.ai.ready", bundle: .safeModule, comment: ""))
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
                .accessibilityLabel(NSLocalizedString("settings.ai.phase_idle", bundle: .safeModule, comment: ""))
        case .downloadingASR, .downloadingDiarization:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
                .accessibilityLabel(NSLocalizedString("settings.ai.downloading", bundle: .safeModule, comment: ""))
        case .loadingASR, .loadingDiarization:
            Image(systemName: "gearshape.circle.fill")
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
                .accessibilityLabel(NSLocalizedString("settings.ai.loading", bundle: .safeModule, comment: ""))
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel(NSLocalizedString("settings.ai.ready", bundle: .safeModule, comment: ""))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(NSLocalizedString("settings.ai.failed", bundle: .safeModule, comment: ""))
        }
    }

    private var providerSection: some View {
        SettingsGroup(NSLocalizedString("settings.ai.provider", bundle: .safeModule, comment: ""), icon: "server.rack") {
            Picker(
                NSLocalizedString("settings.ai.provider_label", bundle: .safeModule, comment: ""),
                selection: $viewModel.settings.aiConfiguration.provider
            ) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.settings.aiConfiguration.provider) { _, newProvider in
                if newProvider != .custom {
                    viewModel.settings.aiConfiguration.baseURL = newProvider.defaultBaseURL
                }
                viewModel.connectionStatus = .unknown
            }
        }
    }

    private var apiConfigurationSection: some View {
        SettingsGroup(NSLocalizedString("settings.ai.api_config", bundle: .safeModule, comment: ""), icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.settings.aiConfiguration.provider == .custom {
                    HStack {
                        Text(NSLocalizedString("settings.ai.base_url", bundle: .safeModule, comment: ""))
                            .frame(width: 80, alignment: .leading)
                        TextField(
                            viewModel.settings.aiConfiguration.provider.defaultBaseURL,
                            text: $viewModel.settings.aiConfiguration.baseURL
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }

                HStack {
                    Text(NSLocalizedString("settings.ai.api_key", bundle: .safeModule, comment: ""))
                        .frame(width: 80, alignment: .leading)
                    Group {
                        if viewModel.showAPIKey {
                            TextField(NSLocalizedString("settings.ai.api_key_placeholder", bundle: .safeModule, comment: ""), text: $viewModel.apiKeyText)
                        } else {
                            SecureField(NSLocalizedString("settings.ai.api_key_placeholder", bundle: .safeModule, comment: ""), text: $viewModel.apiKeyText)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        viewModel.showAPIKey.toggle()
                    } label: {
                        Image(systemName: viewModel.showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(
                        viewModel.showAPIKey
                            ? NSLocalizedString("settings.ai.hide_key", bundle: .safeModule, comment: "")
                            : NSLocalizedString("settings.ai.show_key", bundle: .safeModule, comment: "")
                    )
                }

                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text(NSLocalizedString("settings.ai.keychain_secure", bundle: .safeModule, comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                modelSelectionSection
            }
        }
    }

    // MARK: - Model Selection

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("settings.ai.model", bundle: .safeModule, comment: ""))
                    .frame(width: 80, alignment: .leading)

                if viewModel.isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !viewModel.availableModels.isEmpty {
                    Picker("", selection: $viewModel.settings.aiConfiguration.selectedModel) {
                        Text(NSLocalizedString("settings.ai.model_select", bundle: .safeModule, comment: ""))
                            .tag("")
                        ForEach(viewModel.availableModels) { model in
                            Text(model.id).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(
                        NSLocalizedString("settings.ai.model_placeholder", bundle: .safeModule, comment: ""),
                        text: $viewModel.settings.aiConfiguration.selectedModel
                    )
                    .textFieldStyle(.roundedBorder)
                }

                Button {
                    Task { await viewModel.fetchAvailableModels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoadingModels || !viewModel.settings.aiConfiguration.isValid)
                .help(NSLocalizedString("settings.ai.model_refresh", bundle: .safeModule, comment: ""))
            }

            if let error = viewModel.modelsFetchError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !viewModel.availableModels.isEmpty {
                Text(
                    String(
                        format: NSLocalizedString("settings.ai.models_loaded", bundle: .safeModule, comment: ""),
                        viewModel.availableModels.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(NSLocalizedString("settings.ai.model_hint", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionTestSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        viewModel.testAPIConnection()
                    }) {
                        HStack {
                            if viewModel.connectionStatus == .testing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            }
                            Text(NSLocalizedString("settings.ai.test_connection", bundle: .safeModule, comment: ""))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SettingsDesignSystem.Colors.accent)
                    .disabled(
                        !viewModel.settings.aiConfiguration.isValid ||
                            viewModel.connectionStatus == .testing
                    )

                    Spacer()

                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.connectionStatus.color)
                            .frame(width: 8, height: 8)
                            .symbolEffect(.pulse, isActive: viewModel.connectionStatus == .testing)

                        Text(viewModel.connectionStatus.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let detail = viewModel.connectionStatus.detail, !detail.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                        postProcessingViewModel.editingPrompt = nil
                        postProcessingViewModel.showPromptEditor = true
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
    AISettingsTab()
}

#Preview {
    AISettingsTab()
}
