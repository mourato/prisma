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

    @State private var isAdvancedExpanded = false
    @State private var browserBundleIDsText = ""
    @State private var hasInitializedAdvancedState = false

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

            DisclosureGroup("settings.web_targets.advanced.title".localized, isExpanded: $isAdvancedExpanded) {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text("settings.web_targets.advanced.desc".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(browserLabelKey.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("settings.web_targets.advanced.bundle_ids_desc".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $browserBundleIDsText)
                        .font(.caption.monospaced())
                        .frame(minHeight: 72)
                        .padding(6)
                        .background(MeetingAssistantDesignSystem.Colors.subtleFill2)
                        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))

                    HStack {
                        Spacer()
                        Button("settings.web_targets.advanced.import_common".localized) {
                            selectedBrowsers = Set(WebTargetEditorSupport.commonBrowserBundleIdentifiers)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, MeetingAssistantDesignSystem.Layout.spacing4)
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
        .onAppear {
            guard !hasInitializedAdvancedState else { return }
            hasInitializedAdvancedState = true
            isAdvancedExpanded = false
            browserBundleIDsText = selectedBrowsers.sorted().joined(separator: "\n")
        }
        .onChange(of: selectedBrowsers) { _, newValue in
            let serialized = newValue.sorted().joined(separator: "\n")
            if serialized != browserBundleIDsText {
                browserBundleIDsText = serialized
            }
        }
        .onChange(of: browserBundleIDsText) { _, newValue in
            let parsed = Set(parseBundleIdentifiers(from: newValue))
            if parsed != selectedBrowsers {
                selectedBrowsers = parsed
            }
        }
        .onChange(of: isAdvancedExpanded) { _, isExpanded in
            if !isExpanded {
                selectedBrowsers.removeAll()
            }
        }
    }

    private func parseBundleIdentifiers(from text: String) -> [String] {
        text
            .replacingOccurrences(of: ",", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
