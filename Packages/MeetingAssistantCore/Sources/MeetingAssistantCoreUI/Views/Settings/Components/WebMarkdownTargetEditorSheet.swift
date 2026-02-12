import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct WebMarkdownTargetEditorSheet: View {
    private let target: WebContextTarget?
    private let onSave: (WebContextTarget) -> Void
    private let onCancel: () -> Void

    @State private var displayName: String
    @State private var urlPatternsText: String

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
                urlPatternsText: $urlPatternsText
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
            browserBundleIdentifiers: []
        )
    }
}

#Preview {
    WebMarkdownTargetEditorSheet(
        target: WebContextTarget(
            displayName: "Docs",
            urlPatterns: ["docs.example.com"],
            browserBundleIdentifiers: AppSettingsStore.defaultWebTargetBrowserBundleIdentifiers
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
