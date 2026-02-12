import KeyboardShortcuts
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct AssistantSettingsTab: View {
    @StateObject private var viewModel = AssistantShortcutSettingsViewModel()
    @State private var editingIntegration: AssistantIntegrationConfig?
    @State private var advancedIntegrationDraft: AssistantIntegrationConfig?
    @State private var hoveredHotkeyIntegrationId: UUID?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                headerSection
                assistantControlsSection
                visualFeedbackSection
                optionsSection
                integrationsSection
                testKeysSection
                resetSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $editingIntegration) { integration in
            AssistantIntegrationEditorSheet(
                integration: integration,
                onApplyAndClose: { draft in
                    viewModel.saveIntegration(draft.integration)
                    if let preset = draft.integration.selectedPreset {
                        viewModel.applyPreset(preset, to: draft.integration.id)
                    }
                    editingIntegration = nil
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
            shortcutTitle: "settings.assistant.toggle_command".localized,
            customShortcutLabel: "settings.assistant.custom_shortcut".localized,
            activationModeDescription: "settings.assistant.activation_mode_desc".localized,
            activationMode: $viewModel.activationMode,
            selectedPresetKey: $viewModel.selectedPresetKey
        ) {
            KeyboardShortcuts.Recorder(for: .assistantCommand)
        }
    }

    private var visualFeedbackSection: some View {
        MAGroup(
            "settings.assistant.visual_feedback".localized,
            icon: "rectangle.inset.filled"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                // Border Color Picker
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text("settings.assistant.border_color".localized)
                        .font(.body)
                        .fontWeight(.medium)

                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                        MAThemePicker(selection: $viewModel.borderColor)
                    }
                }

                Divider()

                // Border Style Picker
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
                    .frame(width: MeetingAssistantDesignSystem.Layout.maxPickerWidth)
                }
            }
        }
    }

    private var optionsSection: some View {
        MACard {
            MAToggleRow(
                "settings.assistant.use_escape".localized,
                isOn: $viewModel.useEscapeToCancelRecording
            )
        }
    }

    private var testKeysSection: some View {
        MAGroup(
            "settings.assistant.try_keys".localized,
            icon: "keyboard"
        ) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundStyle(MeetingAssistantDesignSystem.Colors.accent)
                    Text("settings.assistant.try_keys_hint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("", text: $viewModel.testKeysInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 80)
            }
        }
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
                    .controlSize(.small)
                }

                ForEach(viewModel.customIntegrations) { integration in
                    integrationRow(integration: integration, isCardStyle: true)
                }

                if let statusMessage = viewModel.raycastTestStatusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.raycastTestStatusIsError
                            ? MeetingAssistantDesignSystem.Colors.error
                            : MeetingAssistantDesignSystem.Colors.success)
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

            if !isCardStyle {
                KeyboardShortcuts.Recorder(for: .assistantIntegration(integration.id))
                    .controlSize(.small)
                    .frame(minWidth: 132, alignment: .leading)
                    .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
                    .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing6)
                    .background(
                        RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                            .strokeBorder(
                                Color.secondary.opacity(hoveredHotkeyIntegrationId == integration.id ? 0.55 : 0),
                                lineWidth: 1
                            )
                    )
                    .onHover { isHovering in
                        hoveredHotkeyIntegrationId = isHovering ? integration.id : nil
                    }
            }

            if isCardStyle {
                Button {
                    editingIntegration = integration
                } label: {
                    Image(systemName: "pencil")
                        .padding(6)
                        .background(
                            Circle().fill(Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

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

    private var resetSection: some View {
        MACard {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)

                Button(
                    action: { viewModel.resetShortcuts() },
                    label: {
                        Text("settings.assistant.reset".localized)
                    }
                )
                .buttonStyle(.link)

                Spacer()
            }
        }
    }
}

#Preview {
    AssistantSettingsTab()
}
