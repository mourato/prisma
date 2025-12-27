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
            Text(self.isEditing ? NSLocalizedString("prompt.edit_title", bundle: .safeModule, comment: "") : NSLocalizedString("prompt.new_title", bundle: .safeModule, comment: ""))
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("prompt.title_label", bundle: .safeModule, comment: ""))
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(NSLocalizedString("prompt.title_placeholder", bundle: .safeModule, comment: ""), text: self.$title)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("prompt.icon_label", bundle: .safeModule, comment: ""))
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
        .accessibilityLabel(String(format: NSLocalizedString("prompt.icon_accessibility", bundle: .safeModule, comment: ""), icon))
        .accessibilityHint(isSelected ? NSLocalizedString("prompt.icon_selected", bundle: .safeModule, comment: "") : NSLocalizedString("prompt.icon_select", bundle: .safeModule, comment: ""))
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(NSLocalizedString("prompt.description_label", bundle: .safeModule, comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(NSLocalizedString("common.optional", bundle: .safeModule, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField(NSLocalizedString("prompt.description_placeholder", bundle: .safeModule, comment: ""), text: self.$description)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("prompt.instructions_label", bundle: .safeModule, comment: ""))
                .font(.subheadline)
                .fontWeight(.medium)

            Text(NSLocalizedString("prompt.instructions_hint", bundle: .safeModule, comment: ""))
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
            Button(NSLocalizedString("common.cancel", bundle: .safeModule, comment: "")) {
                self.onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button(self.isEditing ? NSLocalizedString("common.save", bundle: .safeModule, comment: "") : NSLocalizedString("common.create", bundle: .safeModule, comment: "")) {
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
