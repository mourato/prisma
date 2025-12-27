import SwiftUI

// MARK: - Prompt Editor Sheet

/// Sheet for creating or editing a post-processing prompt.
public struct PromptEditorSheet: View {
    @State private var title: String
    @State private var promptText: String
    @State private var selectedIcon: String
    @State private var description: String

    private let existingPrompt: PostProcessingPrompt?
    private let onSave: (PostProcessingPrompt) -> Void
    private let onCancel: () -> Void

    private var isEditing: Bool { self.existingPrompt != nil }

    public init(
        prompt: PostProcessingPrompt?,
        onSave: @escaping (PostProcessingPrompt) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingPrompt = prompt
        self.onSave = onSave
        self.onCancel = onCancel

        _title = State(initialValue: prompt?.title ?? "")
        _promptText = State(initialValue: prompt?.promptText ?? "")
        _selectedIcon = State(initialValue: prompt?.icon ?? "doc.text.fill")
        _description = State(initialValue: prompt?.description ?? "")
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            self.header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    self.titleSection
                    self.iconSection
                    self.descriptionSection
                    self.promptSection
                }
                .padding()
            }

            Divider()

            // Footer
            self.footer
        }
        .frame(width: 500, height: 550)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(self.isEditing ? "prompt.edit_title".localized : "prompt.new_title".localized)
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("prompt.title_label".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("prompt.title_placeholder".localized, text: self.$title)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("prompt.icon_label".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PostProcessingPrompt.availableIcons, id: \.self) { icon in
                        self.iconButton(icon)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func iconButton(_ icon: String) -> some View {
        let isSelected = self.selectedIcon == icon

        return Button {
            self.selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("prompt.icon_accessibility".localized(with: icon))
        .accessibilityHint(isSelected ? "prompt.icon_selected".localized : "prompt.icon_select".localized)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("prompt.description_label".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("common.optional".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("prompt.description_placeholder".localized, text: self.$description)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("prompt.instructions_label".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("prompt.instructions_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: self.$promptText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("common.cancel".localized) {
                self.onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button(self.isEditing ? "common.save".localized : "common.create".localized) {
                self.savePrompt()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .disabled(!self.isValid)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Validation

    private var isValid: Bool {
        !self.title.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.promptText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func savePrompt() {
        let prompt = PostProcessingPrompt(
            id: existingPrompt?.id ?? UUID(),
            title: self.title.trimmingCharacters(in: .whitespaces),
            promptText: self.promptText.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: self.existingPrompt?.isActive ?? false,
            icon: self.selectedIcon,
            description: self.description.isEmpty ? nil : self.description.trimmingCharacters(in: .whitespaces),
            isPredefined: false
        )
        self.onSave(prompt)
    }
}

// MARK: - Preview

#Preview("New Prompt") {
    PromptEditorSheet(
        prompt: nil,
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Edit Prompt") {
    PromptEditorSheet(
        prompt: PostProcessingPrompt(
            title: "Resumo Executivo",
            promptText: "Crie um resumo executivo da reunião...",
            icon: "doc.text.magnifyingglass",
            description: "Gera um resumo conciso"
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
