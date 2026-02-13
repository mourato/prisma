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
    private enum Constants {
        static let copyFeedbackDurationNanoseconds: UInt64 = 1_500_000_000
    }

    @State private var draft: AssistantIntegrationEditorDraft
    @State private var copiedPlaceholderToken: String?
    @State private var copiedFeedbackTask: Task<Void, Never>?
    @State private var activePlaceholderPopoverToken: String?
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

            placeholderSection

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

            Button(action: { onOpenAdvanced(draft) }) {
                Label("settings.assistant.integrations.editor.advanced".localized, systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing12)

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
        .onDisappear {
            copiedFeedbackTask?.cancel()
        }
    }

    private var placeholderSection: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            Text("settings.assistant.integrations.editor.placeholders.title".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("settings.assistant.integrations.editor.placeholders.subtitle".localized)
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: MeetingAssistantDesignSystem.Layout.spacing8)],
                alignment: .leading,
                spacing: MeetingAssistantDesignSystem.Layout.spacing8
            ) {
                placeholderButton(token: AssistantIntegrationDeepLinkShortcode.finalText)
                placeholderButton(token: AssistantIntegrationDeepLinkShortcode.finalTextURLEncoded)
                placeholderButton(token: AssistantIntegrationDeepLinkShortcode.rawText)
                placeholderButton(token: AssistantIntegrationDeepLinkShortcode.rawTextURLEncoded)
            }

            if let copiedPlaceholderToken {
                Text(
                    String(
                        format: "settings.assistant.integrations.editor.placeholders.copied".localized,
                        copiedPlaceholderToken
                    )
                )
                .font(.caption)
                .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
            }
        }
    }

    private func placeholderButton(token: String) -> some View {
        let isUsedInDeepLink = draft.integration.deepLink.contains(token)
        let isJustCopied = copiedPlaceholderToken == token

        return HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
            Button {
                copyPlaceholder(token)
            } label: {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                    Text(token)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(isUsedInDeepLink ? Color.accentColor : Color.primary)

                    Spacer()

                    Image(systemName: isUsedInDeepLink ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(isUsedInDeepLink ? Color.accentColor : Color.secondary)
                }
                .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
                .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
                .background(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                        .fill(isUsedInDeepLink ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                        .strokeBorder(isUsedInDeepLink ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .opacity(isJustCopied ? 0.9 : 1)
            }
            .buttonStyle(.plain)
            .help("settings.assistant.integrations.editor.placeholders.copy_help".localized)

            Button {
                activePlaceholderPopoverToken = token
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("settings.assistant.integrations.editor.placeholders.info_help".localized)
            .popover(
                isPresented: Binding(
                    get: { activePlaceholderPopoverToken == token },
                    set: { isPresented in
                        if !isPresented {
                            activePlaceholderPopoverToken = nil
                        }
                    }
                ),
                arrowEdge: .bottom
            ) {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text(token)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(placeholderMeaning(for: token))
                        .font(.callout)

                    VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing4) {
                        Text("settings.assistant.integrations.editor.placeholders.example_title".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(placeholderExample(for: token))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(MeetingAssistantDesignSystem.Layout.spacing12)
                .frame(width: 300, alignment: .leading)
            }
        }
    }

    private func placeholderMeaning(for token: String) -> String {
        switch token {
        case AssistantIntegrationDeepLinkShortcode.finalText:
            return "settings.assistant.integrations.editor.placeholders.final_text.meaning".localized
        case AssistantIntegrationDeepLinkShortcode.finalTextURLEncoded:
            return "settings.assistant.integrations.editor.placeholders.final_text_urlencoded.meaning".localized
        case AssistantIntegrationDeepLinkShortcode.rawText:
            return "settings.assistant.integrations.editor.placeholders.raw_text.meaning".localized
        case AssistantIntegrationDeepLinkShortcode.rawTextURLEncoded:
            return "settings.assistant.integrations.editor.placeholders.raw_text_urlencoded.meaning".localized
        default:
            return ""
        }
    }

    private func placeholderExample(for token: String) -> String {
        switch token {
        case AssistantIntegrationDeepLinkShortcode.finalText:
            return "settings.assistant.integrations.editor.placeholders.final_text.example".localized
        case AssistantIntegrationDeepLinkShortcode.finalTextURLEncoded:
            return "settings.assistant.integrations.editor.placeholders.final_text_urlencoded.example".localized
        case AssistantIntegrationDeepLinkShortcode.rawText:
            return "settings.assistant.integrations.editor.placeholders.raw_text.example".localized
        case AssistantIntegrationDeepLinkShortcode.rawTextURLEncoded:
            return "settings.assistant.integrations.editor.placeholders.raw_text_urlencoded.example".localized
        default:
            return ""
        }
    }

    private func copyPlaceholder(_ token: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)

        copiedFeedbackTask?.cancel()
        copiedPlaceholderToken = token

        copiedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.copyFeedbackDurationNanoseconds)
            copiedPlaceholderToken = nil
        }
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
