import MeetingAssistantCoreCommon
import SwiftUI

struct WebTargetEditorFields: View {
    let nameLabelKey: String
    let urlLabelKey: String
    let urlDescriptionKey: String
    let canSave: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @Binding var displayName: String
    @Binding var urlPatternsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing12) {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text(nameLabelKey.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text(urlLabelKey.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(urlDescriptionKey.localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextEditor(text: $urlPatternsText)
                    .font(.caption.monospaced())
                    .frame(minHeight: 80)
                    .padding(6)
                    .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                    .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
            }

            HStack {
                Spacer()
                Button("common.cancel".localized) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("common.save".localized) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
    }
}

#Preview {
    struct EditorPreviewState {
        var displayName: String
        var urlPatternsText: String
    }

    return PreviewStateContainer(
        EditorPreviewState(
            displayName: "Docs",
            urlPatternsText: "docs.example.com"
        )
    ) { state in
        WebTargetEditorFields(
            nameLabelKey: "settings.meetings.web_targets.name_label",
            urlLabelKey: "settings.meetings.web_targets.url_label",
            urlDescriptionKey: "settings.meetings.web_targets.url_desc",
            canSave: true,
            onSave: {},
            onCancel: {},
            displayName: Binding(
                get: { state.wrappedValue.displayName },
                set: { state.wrappedValue.displayName = $0 }
            ),
            urlPatternsText: Binding(
                get: { state.wrappedValue.urlPatternsText },
                set: { state.wrappedValue.urlPatternsText = $0 }
            )
        )
        .padding()
    }
}
