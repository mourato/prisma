import MeetingAssistantCoreCommon
import SwiftUI

struct WebTargetEditorFields: View {
    let nameLabelKey: String
    let urlLabelKey: String
    let urlDescriptionKey: String
    let browserLabelKey: String
    let canSave: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @Binding var displayName: String
    @Binding var urlPatternsText: String
    @Binding var selectedBrowsers: Set<String>

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

            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Text(browserLabelKey.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(WebTargetEditorSupport.browserOptions) { option in
                    MAToggleRow(
                        option.name,
                        isOn: binding(for: option.bundleIdentifier)
                    )
                }
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

    private func binding(for bundleIdentifier: String) -> Binding<Bool> {
        Binding(
            get: { selectedBrowsers.contains(bundleIdentifier) },
            set: { isSelected in
                if isSelected {
                    selectedBrowsers.insert(bundleIdentifier)
                } else {
                    selectedBrowsers.remove(bundleIdentifier)
                }
            }
        )
    }
}

#Preview {
    struct EditorPreviewState {
        var displayName: String
        var urlPatternsText: String
        var selectedBrowsers: Set<String>
    }

    return PreviewStateContainer(
        EditorPreviewState(
            displayName: "Docs",
            urlPatternsText: "docs.example.com",
            selectedBrowsers: Set(WebTargetEditorSupport.defaultBrowserBundleIdentifiers)
        )
    ) { state in
        WebTargetEditorFields(
            nameLabelKey: "settings.meetings.web_targets.name_label",
            urlLabelKey: "settings.meetings.web_targets.url_label",
            urlDescriptionKey: "settings.meetings.web_targets.url_desc",
            browserLabelKey: "settings.meetings.web_targets.browser_label",
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
            ),
            selectedBrowsers: Binding(
                get: { state.wrappedValue.selectedBrowsers },
                set: { state.wrappedValue.selectedBrowsers = $0 }
            )
        )
        .padding()
    }
}
