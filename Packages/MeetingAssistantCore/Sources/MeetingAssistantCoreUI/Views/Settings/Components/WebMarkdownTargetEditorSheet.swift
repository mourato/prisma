import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct WebMarkdownTargetEditorSheet: View {
    private let target: WebContextTarget?
    private let onSave: (WebContextTarget) -> Void
    private let onCancel: () -> Void

    @State private var displayName: String
    @State private var urlPatternsText: String
    @State private var forceMarkdownOutput: Bool
    @State private var outputLanguage: DictationOutputLanguage
    @State private var autoStartMeetingRecording: Bool

    public init(
        target: WebContextTarget?,
        onSave: @escaping (WebContextTarget) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.target = target
        self.onSave = onSave
        self.onCancel = onCancel

        _displayName = State(initialValue: target?.displayName ?? "")
        _urlPatternsText = State(initialValue: (target?.urlPatterns ?? []).joined(separator: "\n"))
        _forceMarkdownOutput = State(initialValue: target?.forceMarkdownOutput ?? true)
        _outputLanguage = State(initialValue: target?.outputLanguage ?? .original)
        _autoStartMeetingRecording = State(initialValue: target?.autoStartMeetingRecording ?? false)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            Text("settings.markdown_targets.websites.editor_title".localized)
                .font(.headline)

            WebTargetEditorFields(
                nameLabelKey: "settings.markdown_targets.websites.name_label",
                urlLabelKey: "settings.markdown_targets.websites.url_label",
                urlDescriptionKey: "settings.markdown_targets.websites.url_desc",
                canSave: canSave,
                onSave: { onSave(buildTarget()) },
                onCancel: onCancel,
                displayName: $displayName,
                urlPatternsText: $urlPatternsText,
                additionalContent: {
                    MAToggleRow(
                        "settings.rules_per_app.markdown.title".localized,
                        isOn: $forceMarkdownOutput
                    )

                    HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
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

                    MAToggleRow(
                        "settings.markdown_targets.websites.auto_record.title".localized,
                        description: "settings.markdown_targets.websites.auto_record.desc".localized,
                        isOn: $autoStartMeetingRecording
                    )
                }
            )
        }
        .padding()
        .frame(minWidth: 420)
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !parsedURLPatterns.isEmpty
    }

    private var parsedURLPatterns: [String] {
        WebTargetEditorSupport.parseURLPatterns(from: urlPatternsText)
    }

    private func buildTarget() -> WebContextTarget {
        WebContextTarget(
            id: target?.id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            urlPatterns: parsedURLPatterns,
            browserBundleIdentifiers: [],
            forceMarkdownOutput: forceMarkdownOutput,
            outputLanguage: outputLanguage,
            autoStartMeetingRecording: autoStartMeetingRecording
        )
    }
}

#Preview {
    WebMarkdownTargetEditorSheet(
        target: WebContextTarget(
            displayName: "Docs",
            urlPatterns: ["docs.example.com"],
            browserBundleIdentifiers: AppSettingsStore.defaultWebTargetBrowserBundleIdentifiers,
            forceMarkdownOutput: true,
            outputLanguage: .english,
            autoStartMeetingRecording: true
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
