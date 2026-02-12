import KeyboardShortcuts
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct AssistantIntegrationEditorDraft: Equatable {
    public var integration: AssistantIntegrationConfig

    public init(integration: AssistantIntegrationConfig) {
        self.integration = integration
    }
}

public struct AssistantIntegrationEditorSheet: View {
    @State private var draft: AssistantIntegrationEditorDraft
    private let onApplyAndClose: (AssistantIntegrationEditorDraft) -> Void
    private let onDelete: (UUID) -> Void
    private let onOpenAdvanced: (AssistantIntegrationEditorDraft) -> Void

    public init(
        integration: AssistantIntegrationConfig,
        onApplyAndClose: @escaping (AssistantIntegrationEditorDraft) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onOpenAdvanced: @escaping (AssistantIntegrationEditorDraft) -> Void
    ) {
        _draft = State(initialValue: AssistantIntegrationEditorDraft(integration: integration))
        self.onApplyAndClose = onApplyAndClose
        self.onDelete = onDelete
        self.onOpenAdvanced = onOpenAdvanced
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
            Text("settings.assistant.integrations.editor.title.integration".localized)
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.assistant.integrations.integration_name".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("", text: $draft.integration.name)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("settings.assistant.integrations.integration_enabled".localized, isOn: $draft.integration.isEnabled)

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.assistant.integrations.integration_deeplink".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("", text: $draft.integration.deepLink)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.assistant.integrations.editor.hotkey".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MAShortcutControlsRow(
                    title: "settings.assistant.integrations.editor.hotkey_config".localized,
                    activationMode: $draft.integration.shortcutActivationMode,
                    selectedPresetKey: $draft.integration.shortcutPresetKey
                )

                if draft.integration.shortcutPresetKey == .custom {
                    MAShortcutRecorderRow(label: "settings.shortcuts.custom_shortcut".localized) {
                        KeyboardShortcuts.Recorder(for: .assistantIntegration(draft.integration.id))
                    }
                }
            }

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text("settings.assistant.integrations.editor.instructions".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: Binding(
                    get: { draft.integration.promptInstructions ?? "" },
                    set: { draft.integration.promptInstructions = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                        .strokeBorder(.separator, lineWidth: 1)
                )
            }

            presetSection

            Button(action: { onOpenAdvanced(draft) }) {
                Label("settings.assistant.integrations.editor.advanced".localized, systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            HStack {
                Button(role: .destructive) {
                    onDelete(draft.integration.id)
                } label: {
                    Text("settings.assistant.integrations.editor.delete".localized)
                }

                Spacer()

                Button("settings.assistant.integrations.editor.close".localized) {
                    onApplyAndClose(draft)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(MeetingAssistantDesignSystem.Layout.spacing20)
        .frame(minWidth: 560, minHeight: 480)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Text("settings.assistant.integrations.editor.presets".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: MeetingAssistantDesignSystem.Layout.spacing8)],
                      alignment: .leading,
                      spacing: MeetingAssistantDesignSystem.Layout.spacing8)
            {
                ForEach(AssistantIntegrationPreset.allCases, id: \.self) { preset in
                    presetChip(for: preset)
                }
            }
        }
    }

    @ViewBuilder
    private func presetChip(for preset: AssistantIntegrationPreset) -> some View {
        let isSelected = draft.integration.selectedPreset == preset
        let borderColor: Color = isSelected ? .accentColor : Color.secondary.opacity(0.25)
        let fillColor: Color = isSelected ? .accentColor.opacity(0.12) : .clear

        Button {
            draft.integration.selectedPreset = preset
        } label: {
            Text(preset.localizedName)
                .font(.callout)
                .lineLimit(1)
                .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing12)
                .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Assistant Integration Editor") {
    AssistantIntegrationEditorSheet(
        integration: AssistantIntegrationConfig.defaultRaycast,
        onApplyAndClose: { _ in },
        onDelete: { _ in },
        onOpenAdvanced: { _ in }
    )
}
