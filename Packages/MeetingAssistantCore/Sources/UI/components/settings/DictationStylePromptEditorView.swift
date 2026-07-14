import MeetingAssistantCoreCommon
import SwiftUI

public struct DictationStylePromptEditorView: View {
    @Binding private var promptInstructions: String
    @FocusState private var isPromptEditorFocused: Bool
    private let onCancel: () -> Void

    public init(
        promptInstructions: Binding<String>,
        onCancel: @escaping () -> Void,
    ) {
        _promptInstructions = promptInstructions
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.styles.editor.prompt_hint".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextEditor(text: $promptInstructions)
                    .font(.body)
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .focused($isPromptEditorFocused)
                    .padding(AppDesignSystem.Layout.textAreaPadding)
                    .background(AppDesignSystem.Colors.subtleFill2)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
                    .accessibilityLabel("settings.styles.editor.prompt".localized)
            }
            .padding()
        }
        .onAppear {
            isPromptEditorFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                onCancel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("settings.styles.editor.prompt".localized)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("settings.styles.editor.prompt".localized)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            SettingsTitleBarMaterialBackground(usesBottomFade: false)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

#Preview("Prompt Editor") {
    DictationStylePromptEditorView(
        promptInstructions: .constant("Prefer concise bullets and list action items at the end."),
        onCancel: {},
    )
}
