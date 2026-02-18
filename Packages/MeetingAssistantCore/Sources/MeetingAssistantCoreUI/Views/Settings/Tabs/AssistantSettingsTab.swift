import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import Foundation
import SwiftUI

public struct AssistantSettingsTab: View {
    private enum Constants {
        static let previewDurationNanoseconds: UInt64 = 2_000_000_000
    }

    @StateObject private var viewModel = AssistantShortcutSettingsViewModel()
    @StateObject private var integrationViewModel = IntegrationSettingsViewModel()
    @State private var previewController: AssistantScreenBorderController?
    @State private var previewTask: Task<Void, Never>?
    @State private var isPreviewRunning = false
    @State private var glowSizeInput = ""
    @State private var editingIntegration: AssistantIntegrationConfig?
    @State private var advancedIntegrationDraft: AssistantIntegrationConfig?
    @State private var integrationShortcutConflictMessages: [UUID: String] = [:]

    public init() {}

    public var body: some View {
        SettingsScrollableContent {
            headerSection
            assistantControlsSection
            integrationsSection
            visualFeedbackSection
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
        .sheet(item: $editingIntegration) { integration in
            AssistantIntegrationEditorSheet(
                integration: integration,
                onApplyAndClose: { draft in
                    if let conflictMessage = integrationViewModel.saveIntegrationWithModifierValidation(draft.integration) {
                        return conflictMessage
                    }
                    editingIntegration = nil
                    return nil
                },
                onDelete: { id in
                    integrationViewModel.removeIntegration(id: id)
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
                scriptTestOutput: integrationViewModel.scriptTestOutput,
                scriptTestErrorMessage: integrationViewModel.scriptTestErrorMessage,
                onSave: { scriptConfig in
                    var updated = integration
                    updated.advancedScript = scriptConfig
                    integrationViewModel.saveIntegration(updated)
                    advancedIntegrationDraft = nil
                    integrationViewModel.clearScriptTestResult()
                },
                onTest: { script, input in
                    await integrationViewModel.testScript(script: script, input: input)
                },
                onClose: {
                    advancedIntegrationDraft = nil
                    integrationViewModel.clearScriptTestResult()
                }
            )
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

                    MAActionLayerKeyEditor(
                        title: "settings.assistant.layer.assistant_key".localized,
                        key: $viewModel.assistantLayerShortcutKey,
                        conflictMessage: viewModel.assistantLayerShortcutConflictMessage
                    )

                    Text("settings.assistant.layer.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    MAToggleRow(
                        "settings.assistant.use_escape".localized,
                        isOn: $viewModel.useEscapeToCancelRecording
                    )
                }
            }
        )
    }

    private var integrationsSection: some View {
        AssistantIntegrationsSection(
            viewModel: integrationViewModel,
            editingIntegration: $editingIntegration,
            integrationShortcutConflictMessages: $integrationShortcutConflictMessages
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
}

#Preview {
    AssistantSettingsTab()
}
