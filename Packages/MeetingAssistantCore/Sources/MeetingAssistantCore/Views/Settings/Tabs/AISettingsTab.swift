import os.log
import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct AISettingsTab: View {
    @StateObject private var viewModel = AISettingsViewModel(settings: .shared)

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                mainSection

                if viewModel.settings.aiEnabled {
                    providerSection
                    apiConfigurationSection
                    connectionTestSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var mainSection: some View {
        SettingsGroup(NSLocalizedString("settings.general.title", bundle: .safeModule, comment: ""), icon: "brain") {
            Toggle(
                NSLocalizedString("settings.ai.enabled", bundle: .safeModule, comment: ""),
                isOn: $viewModel.settings.aiEnabled
            )

            Text(NSLocalizedString("settings.ai.description", bundle: .safeModule, comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            Toggle(
                NSLocalizedString("settings.ai.diarization", bundle: .safeModule, comment: ""),
                isOn: $viewModel.settings.isDiarizationEnabled
            )

            Text(NSLocalizedString("settings.ai.diarization_desc", bundle: .safeModule, comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.settings.isDiarizationEnabled {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 12) {
                    HStack {
                        Toggle(
                            NSLocalizedString(
                                "settings.ai.num_speakers", bundle: .safeModule, comment: ""
                            ),
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
                        .toggleStyle(.checkbox)

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
                    }

                    if viewModel.settings.numSpeakers == nil {
                        HStack {
                            Toggle(
                                NSLocalizedString(
                                    "settings.ai.min_speakers", bundle: .safeModule, comment: ""
                                ),
                                isOn: Binding(
                                    get: { viewModel.settings.minSpeakers != nil },
                                    set: { isOn in
                                        viewModel.settings.minSpeakers = isOn ? 1 : nil
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)

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
                        }

                        HStack {
                            Toggle(
                                NSLocalizedString(
                                    "settings.ai.max_speakers", bundle: .safeModule, comment: ""
                                ),
                                isOn: Binding(
                                    get: { viewModel.settings.maxSpeakers != nil },
                                    set: { isOn in
                                        viewModel.settings.maxSpeakers = isOn ? 10 : nil
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)

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
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
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

    @ViewBuilder
    private var apiConfigurationSection: some View {
        SettingsGroup(NSLocalizedString("settings.ai.api_config", bundle: .safeModule, comment: ""), icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(NSLocalizedString("settings.ai.base_url", bundle: .safeModule, comment: ""))
                        .frame(width: 80, alignment: .leading)
                    TextField(
                        viewModel.settings.aiConfiguration.provider.defaultBaseURL,
                        text: $viewModel.settings.aiConfiguration.baseURL
                    )
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text(NSLocalizedString("settings.ai.api_key", bundle: .safeModule, comment: ""))
                        .frame(width: 80, alignment: .leading)
                    Group {
                        if viewModel.showAPIKey {
                            TextField("sk-...", text: $viewModel.apiKeyText)
                        } else {
                            SecureField("sk-...", text: $viewModel.apiKeyText)
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

    @ViewBuilder
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
                        "gpt-4o, claude-3-5-sonnet...",
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

    @ViewBuilder
    private var connectionTestSection: some View {
        SettingsCard {
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
        }
    }
}

#Preview {
    AISettingsTab()
}

#Preview {
    AISettingsTab()
}
