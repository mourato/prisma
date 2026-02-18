import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import Foundation
import SwiftUI

public struct IntegrationsSettingsTab: View {
    @StateObject private var viewModel = IntegrationSettingsViewModel()
    @State private var editingIntegration: AssistantIntegrationConfig?
    @State private var advancedIntegrationDraft: AssistantIntegrationConfig?
    @State private var integrationShortcutConflictMessages: [UUID: String] = [:]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.sectionSpacing) {
                headerSection
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
    }

    private var headerSection: some View {
        Text("settings.integrations.header_desc".localized)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

            MAActionLayerKeyEditor(
                title: "settings.assistant.layer.integration_key".localized,
                key: integrationLayerKeyBinding(for: integration.id),
                conflictMessage: integrationShortcutConflictMessages[integration.id],
                maxInputWidth: 74
            )
            .frame(maxWidth: 180)

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

    private func integrationLayerKeyBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                viewModel.integration(for: id)?.layerShortcutKey ?? ""
            },
            set: { newValue in
                let conflictMessage = viewModel.setIntegrationLayerShortcutKey(newValue, for: id)
                integrationShortcutConflictMessages[id] = conflictMessage
            }
        )
    }
}

#Preview {
    IntegrationsSettingsTab()
}
