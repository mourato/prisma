import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct AssistantIntegrationsSection: View {
    @ObservedObject private var viewModel: IntegrationSettingsViewModel
    @Binding private var editingIntegration: AssistantIntegrationConfig?

    public init(
        viewModel: IntegrationSettingsViewModel,
        editingIntegration: Binding<AssistantIntegrationConfig?>
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _editingIntegration = editingIntegration
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

            VStack(alignment: .trailing, spacing: MeetingAssistantDesignSystem.Layout.spacing2) {
                Text("settings.assistant.integrations.shortcut.direct".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(shortcutSummary(for: integration))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

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

    private func shortcutSummary(for integration: AssistantIntegrationConfig) -> String {
        guard let shortcut = integration.shortcutDefinition else {
            return "settings.assistant.integrations.shortcut.not_configured".localized
        }

        let modifierTokens = shortcut.modifiers.map { modifier in
            switch modifier {
            case .leftCommand, .rightCommand, .command:
                "⌘"
            case .leftShift, .rightShift, .shift:
                "⇧"
            case .leftOption, .rightOption, .option:
                "⌥"
            case .leftControl, .rightControl, .control:
                "⌃"
            case .fn:
                "Fn"
            }
        }
        let primary = shortcut.primaryKey?.display ?? ""
        return (modifierTokens + [primary]).joined(separator: " ")
    }
}

#Preview {
    AssistantIntegrationsSection(
        viewModel: IntegrationSettingsViewModel(),
        editingIntegration: .constant(nil)
    )
}
