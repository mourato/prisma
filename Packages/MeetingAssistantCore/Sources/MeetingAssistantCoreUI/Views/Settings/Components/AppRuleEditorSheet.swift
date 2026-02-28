import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct AppRuleEditorSheet: View {
    private let resolvedRule: ResolvedDictationAppRule
    private let onSave: (_ forceMarkdownOutput: Bool, _ outputLanguage: DictationOutputLanguage, _ customPromptInstructions: String?) -> Void
    private let onCancel: () -> Void

    @State private var forceMarkdownOutput: Bool
    @State private var outputLanguage: DictationOutputLanguage
    @State private var customPromptInstructions: String

    public init(
        resolvedRule: ResolvedDictationAppRule,
        onSave: @escaping (_ forceMarkdownOutput: Bool, _ outputLanguage: DictationOutputLanguage, _ customPromptInstructions: String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.resolvedRule = resolvedRule
        self.onSave = onSave
        self.onCancel = onCancel

        _forceMarkdownOutput = State(initialValue: resolvedRule.rule.forceMarkdownOutput)
        _outputLanguage = State(initialValue: resolvedRule.rule.outputLanguage)
        _customPromptInstructions = State(initialValue: resolvedRule.rule.customPromptInstructions ?? "")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing12) {
            Text("settings.rules_per_app.editor_title".localized(with: resolvedRule.displayName))
                .font(.headline)

            Text(resolvedRule.rule.bundleIdentifier)
                .font(.caption)
                .foregroundStyle(.secondary)

            DSToggleRow(
                "settings.rules_per_app.markdown.title".localized,
                isOn: $forceMarkdownOutput
            )

            HStack(spacing: AppDesignSystem.Layout.spacing12) {
                Text("settings.rules_per_app.language.title".localized)
                    .font(.body)
                    .fontWeight(.regular)

                Spacer()

                Picker(
                    "settings.rules_per_app.language.title".localized,
                    selection: $outputLanguage
                ) {
                    ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing8) {
                Text("settings.rules_per_app.custom_prompt.title".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("settings.rules_per_app.custom_prompt.hint".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextEditor(text: $customPromptInstructions)
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(AppDesignSystem.Layout.textAreaPadding)
                    .background(AppDesignSystem.Colors.subtleFill2)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
            }

            HStack {
                Spacer()
                Button("common.cancel".localized) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("common.save".localized) {
                    let normalized = customPromptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        forceMarkdownOutput,
                        outputLanguage,
                        normalized.isEmpty ? nil : normalized
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 460)
    }
}

#Preview {
    AppRuleEditorSheet(
        resolvedRule: ResolvedDictationAppRule(
            rule: DictationAppRule(
                bundleIdentifier: "com.hnc.Discord",
                forceMarkdownOutput: true,
                outputLanguage: .english,
                customPromptInstructions: "Write everything in lowercase."
            ),
            displayName: "Discord"
        ),
        onSave: { _, _, _ in },
        onCancel: {}
    )
}
