import MeetingAssistantCoreCommon
import SwiftUI

public struct SummaryTemplateEditorSheet: View {
    private enum Constants {
        static let sheetWidth: CGFloat = 520
        static let sheetHeight: CGFloat = 460
        static let editorMinHeight: CGFloat = 280
    }

    @State private var summaryTemplate: String
    private let onSave: (String) -> Void
    private let onCancel: () -> Void

    public init(
        initialTemplate: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _summaryTemplate = State(initialValue: initialTemplate)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing16) {
                    Text("settings.meetings.template_desc".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("settings.meetings.template.editor_hint".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $summaryTemplate)
                        .font(.body.monospaced())
                        .frame(minHeight: Constants.editorMinHeight)
                        .padding(MeetingAssistantDesignSystem.Layout.textAreaPadding)
                        .background(MeetingAssistantDesignSystem.Colors.textBackground)
                        .clipShape(RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                                .stroke(MeetingAssistantDesignSystem.Colors.separator, lineWidth: 1)
                        )
                }
                .padding()
            }

            Divider()
            footer
        }
        .frame(width: Constants.sheetWidth, height: Constants.sheetHeight)
    }

    private var header: some View {
        HStack {
            Text("settings.meetings.template.editor_title".localized)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(MeetingAssistantDesignSystem.Colors.windowBackground)
    }

    private var footer: some View {
        HStack {
            Button("common.cancel".localized) {
                onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button("common.save".localized) {
                onSave(summaryTemplate.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .tint(MeetingAssistantDesignSystem.Colors.accent)
            .disabled(summaryTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(MeetingAssistantDesignSystem.Colors.windowBackground)
    }
}

#Preview {
    SummaryTemplateEditorSheet(
        initialTemplate: """
        # {{meeting_title}}
        - Date: {{meeting_date}}

        {{summary}}
        """,
        onSave: { _ in },
        onCancel: {}
    )
}
