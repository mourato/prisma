import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct AssistantSettingsTab: View {
    private enum Constants {
        static let previewDurationNanoseconds: UInt64 = 2_000_000_000
    }

    @StateObject private var viewModel = AssistantShortcutSettingsViewModel()
    @State private var editingIntegration: AssistantIntegrationConfig?
    @State private var advancedIntegrationDraft: AssistantIntegrationConfig?
    @State private var integrationShortcutConflictMessages: [UUID: String] = [:]
    @State private var previewController: AssistantScreenBorderController?
    @State private var previewTask: Task<Void, Never>?
    @State private var isPreviewRunning = false
    @State private var glowSizeInput = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                headerSection
                assistantControlsSection
                visualFeedbackSection
                integrationsSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $editingIntegration) { integration in
            AssistantIntegrationEditorSheet(
                integration: integration,
                onApplyAndClose: { draft in
                    if let conflictMessage = viewModel.saveIntegrationWithModifierValidation(draft.integration) {
                        return conflictMessage
                    }
                    editingIntegration = nil
                    return nil
                },
                onDelete: { id in
                    viewModel.removeIntegration(id: id)
                    editingIntegration = nil
                },
                onOpenAdvanced: { draft in
                    advancedIntegrationDraft = draft.integration
                    editingIntegration = nil
                }
            )
        }
        .sheet(item: $advancedIntegrationDraft) { integration in
            AssistantIntegrationBashScriptSheet(
                scriptConfig: integration.advancedScript,
                scriptTestOutput: viewModel.scriptTestOutput,
                scriptTestErrorMessage: viewModel.scriptTestErrorMessage,
                onSave: { scriptConfig in
                    var updated = integration
                    updated.advancedScript = scriptConfig
                    viewModel.saveIntegration(updated)
                    advancedIntegrationDraft = nil
                    viewModel.clearScriptTestResult()
                },
                onTest: { script, input in
                    await viewModel.testScript(script: script, input: input)
                },
                onClose: {
                    advancedIntegrationDraft = nil
                    viewModel.clearScriptTestResult()
                }
            )
        }
        .onAppear {
            glowSizeInput = String(Int(viewModel.glowSize))
        }
        .onChange(of: viewModel.glowSize) { _, newValue in
            let normalized = String(Int(newValue))
            if glowSizeInput != normalized {
                glowSizeInput = normalized
            }
        }
        .onDisappear {
            stopPreviewIfNeeded()
        }
    }

    private var headerSection: some View {
        Text("settings.assistant.header_desc".localized)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assistantControlsSection: some View {
        MAShortcutSettingsSection(
            groupTitle: "settings.assistant.controls".localized,
            groupIcon: "sparkles",
            descriptionText: "settings.assistant.toggle_command_desc".localized,
            settingsContent: {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    MAModifierShortcutEditor(
                        shortcut: $viewModel.assistantShortcutDefinition,
                        conflictMessage: viewModel.assistantModifierConflictMessage
                    )

                    Divider()

                    MAToggleRow(
                        "settings.assistant.use_escape".localized,
                        isOn: $viewModel.useEscapeToCancelRecording
                    )
                }
            }
        )
    }

    private var visualFeedbackSection: some View {
        MAGroup(
            "settings.assistant.visual_feedback".localized,
            icon: "rectangle.inset.filled"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                    Text("settings.assistant.border_color".localized)
                        .font(.body)
                        .fontWeight(.medium)
                        
                    Spacer()

                    MAThemePicker(
                        selection: $viewModel.borderColor,
                        circleSpacing: MeetingAssistantDesignSystem.Layout.spacing4,
                        itemFrameSize: 34
                    )
                }

                Divider()

                HStack {
                    Text("settings.assistant.border_style".localized)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    Picker("", selection: $viewModel.borderStyle) {
                        ForEach(AssistantBorderStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Divider()

                if viewModel.borderStyle == .stroke {
                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                        Text("settings.assistant.border_width".localized)
                            .font(.body)
                            .fontWeight(.medium)

                        Spacer()
                        
                        previewButton

                        Picker("", selection: borderWidthSelection) {
                            ForEach(AssistantShortcutSettingsViewModel.borderWidthOptions, id: \.self) { option in
                                Text("\(Int(option)) pt").tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                    }
                } else {
                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                        Text("settings.assistant.glow_size".localized)
                            .font(.body)
                            .fontWeight(.medium)

                        Spacer()
                        
                        previewButton

                        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                            TextField("", text: glowSizeInputBinding)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 56)

                            Text("pt")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        
                    }
                }
            }
        }
    }

    private var previewButton: some View {
        Button("settings.assistant.preview".localized) {
            runVisualFeedbackPreview()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isPreviewRunning)
    }

    private var borderWidthSelection: Binding<Double> {
        Binding(
            get: { nearestBorderWidthOption(for: viewModel.borderWidth) },
            set: { viewModel.borderWidth = $0 }
        )
    }

    private var glowSizeInputBinding: Binding<String> {
        Binding(
            get: { glowSizeInput },
            set: { newValue in
                let digitsOnly = String(newValue.filter(\.isNumber))
                glowSizeInput = digitsOnly
                if let numericValue = Int(digitsOnly) {
                    viewModel.glowSize = Double(numericValue)
                } else if digitsOnly.isEmpty {
                    viewModel.glowSize = 0
                }
            }
        )
    }

    private func nearestBorderWidthOption(for value: Double) -> Double {
        AssistantShortcutSettingsViewModel.borderWidthOptions.min(
            by: { abs($0 - value) < abs($1 - value) }
        ) ?? AssistantShortcutSettingsViewModel.borderWidthOptions[1]
    }

    private func runVisualFeedbackPreview() {
        guard !isPreviewRunning else { return }

        let settings = AppSettingsStore.shared
        settings.assistantBorderStyle = viewModel.borderStyle
        settings.assistantBorderWidth = nearestBorderWidthOption(for: viewModel.borderWidth)
        settings.assistantGlowSize = max(0, viewModel.glowSize)

        let controller = AssistantScreenBorderController(settingsStore: settings)
        previewController = controller
        isPreviewRunning = true
        controller.show()

        previewTask?.cancel()
        previewTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.previewDurationNanoseconds)
            controller.hide()
            previewController = nil
            isPreviewRunning = false
        }
    }

    private func stopPreviewIfNeeded() {
        previewTask?.cancel()
        previewTask = nil
        previewController?.hide()
        previewController = nil
        isPreviewRunning = false
    }

    private var integrationsSection: some View {
        MAGroup(
            "settings.assistant.integrations.title".localized,
            icon: "puzzlepiece.extension"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                Text("settings.assistant.integrations.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text("settings.assistant.integrations.built_in".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.builtInIntegrations) { integration in
                    integrationRow(integration: integration, isCardStyle: false)
                }

                Divider()

                HStack {
                    Text("settings.assistant.integrations.custom".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        viewModel.addIntegration()
                    } label: {
                        Label(
                            "settings.assistant.integrations.new".localized,
                            systemImage: "plus"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                ForEach(viewModel.customIntegrations) { integration in
                    integrationRow(integration: integration, isCardStyle: true)
                }

                if let statusMessage = viewModel.raycastTestStatusMessage {
                    let statusColor = viewModel.raycastTestStatusIsError
                        ? MeetingAssistantDesignSystem.Colors.error
                        : MeetingAssistantDesignSystem.Colors.success

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
        }
    }

    private func integrationRow(integration: AssistantIntegrationConfig, isCardStyle: Bool) -> some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            if isCardStyle {
                RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    )
            }

            Text(integration.name)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            MAModifierShortcutEditor(
                shortcut: integrationShortcutBinding(for: integration.id),
                conflictMessage: integrationShortcutConflictMessages[integration.id],
                showsTitle: false,
                maxInputWidth: 260
            )

            Button {
                editingIntegration = integration
            } label: {
                Image(systemName: "pencil")
                    .padding(MeetingAssistantDesignSystem.Layout.compactInset)
                    .background(
                        Circle().fill(Color.secondary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { integration.isEnabled },
                set: { newValue in
                    viewModel.setIntegrationEnabled(newValue, for: integration.id)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(isCardStyle ? MeetingAssistantDesignSystem.Layout.spacing12 : 0)
        .background(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.cardCornerRadius)
                .strokeBorder(isCardStyle ? Color.secondary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    private func integrationShortcutBinding(for id: UUID) -> Binding<ShortcutDefinition?> {
        Binding(
            get: {
                viewModel.integration(for: id)?.shortcutDefinition
            },
            set: { newValue in
                let conflictMessage = viewModel.setIntegrationShortcutDefinition(newValue, for: id)
                integrationShortcutConflictMessages[id] = conflictMessage
            }
        )
    }

}

#Preview {
    AssistantSettingsTab()
}
