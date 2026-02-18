import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import Foundation
import SwiftUI

public struct AssistantIntegrationsSection: View {
    @ObservedObject private var viewModel: IntegrationSettingsViewModel
    @Binding private var editingIntegration: AssistantIntegrationConfig?
    @Binding private var integrationShortcutConflictMessages: [UUID: String]

    public init(
        viewModel: IntegrationSettingsViewModel,
        editingIntegration: Binding<AssistantIntegrationConfig?>,
        integrationShortcutConflictMessages: Binding<[UUID: String]>
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _editingIntegration = editingIntegration
        _integrationShortcutConflictMessages = integrationShortcutConflictMessages
    }

    public var body: some View {
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
    AssistantIntegrationsSection(
        viewModel: IntegrationSettingsViewModel(),
        editingIntegration: .constant(nil),
        integrationShortcutConflictMessages: .constant([:])
    )
}
