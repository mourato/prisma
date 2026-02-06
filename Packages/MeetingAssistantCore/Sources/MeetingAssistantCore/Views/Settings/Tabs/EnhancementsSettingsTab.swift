import SwiftUI

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct EnhancementsSettingsTab: View {
    @StateObject private var viewModel = AISettingsViewModel(settings: .shared)
    @StateObject private var postProcessingViewModel = PostProcessingSettingsViewModel()

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
        .sheet(isPresented: $postProcessingViewModel.showSystemPromptEditor) {
            SystemPromptEditorSheet(
                initialPrompt: postProcessingViewModel.settings.systemPrompt,
                onSave: postProcessingViewModel.handleSaveSystemPrompt,
                onCancel: { postProcessingViewModel.showSystemPromptEditor = false },
                onRestoreDefault: { postProcessingViewModel.resetSystemPrompt() }
            )
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
}

#Preview {
    EnhancementsSettingsTab()
}
