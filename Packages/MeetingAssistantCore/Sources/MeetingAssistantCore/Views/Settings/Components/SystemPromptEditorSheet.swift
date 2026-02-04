import SwiftUI

// MARK: - System Prompt Editor Sheet

/// Sheet for editing the AI system guidelines.
struct SystemPromptEditorSheet: View {
    @State private var systemPrompt: String
    private let onSave: (String) -> Void
    private let onCancel: () -> Void
    private let onRestoreDefault: () -> Void

    init(
        initialPrompt: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onRestoreDefault: @escaping () -> Void
    ) {
        _systemPrompt = State(initialValue: initialPrompt)
        self.onSave = onSave
        self.onCancel = onCancel
        self.onRestoreDefault = onRestoreDefault
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    instructionSection
                    editorSection
                }
                .padding()
            }

            Divider()
            footer
        }
        .frame(width: 500, height: 450)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("settings.post_processing.system_prompt_editor_title".localized)
                .font(.headline)
            Spacer()

            Button("settings.post_processing.restore_default".localized) {
                onRestoreDefault()
            }
            .buttonStyle(.plain)
            .foregroundStyle(SettingsDesignSystem.Colors.accent)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(SettingsDesignSystem.Colors.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Sections

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("settings.post_processing.base_instructions".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("prompt.instructions_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var editorSection: some View {
        TextEditor(text: $systemPrompt)
            .font(.body)
            .frame(minHeight: 250)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("common.cancel".localized) {
                onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button("common.save".localized) {
                onSave(systemPrompt)
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .tint(SettingsDesignSystem.Colors.accent)
            .disabled(systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    SystemPromptEditorSheet(
        initialPrompt: "Analise a transcrição e gere notas de reunião...",
        onSave: { _ in },
        onCancel: {},
        onRestoreDefault: {}
    )
}
