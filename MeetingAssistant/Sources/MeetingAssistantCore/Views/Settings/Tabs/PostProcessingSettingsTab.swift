import SwiftUI

// MARK: - Post-Processing Settings Tab

/// Settings tab for configuring AI post-processing prompts.
public struct PostProcessingSettingsTab: View {
    @StateObject private var viewModel = PostProcessingSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                self.enableToggleSection

                if self.viewModel.settings.postProcessingEnabled {
                    if self.viewModel.settings.aiConfiguration.isValid {
                        self.systemPromptSection
                        self.userPromptsSection
                    } else {
                        self.connectionWarningSection
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: self.$viewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: self.viewModel.editingPrompt,
                onSave: self.viewModel.handleSavePrompt,
                onCancel: { self.viewModel.showPromptEditor = false }
            )
        }
        .alert("Excluir Prompt?", isPresented: self.$viewModel.showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                self.viewModel.executeDelete()
            }
        } message: {
            if let prompt = self.viewModel.promptToDelete {
                Text("Tem certeza que deseja excluir o prompt \"\(prompt.title)\"? Esta ação não pode ser desfeita.")
            }
        }
    }

    // MARK: - Sections

    private var enableToggleSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Habilitar Pós-Processamento com IA", isOn: self.$viewModel.settings.postProcessingEnabled)
                    .font(.headline)

                Text("Quando habilitado, as transcrições serão automaticamente processadas por IA para gerar resumos e correções.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionWarningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Conexão com IA não configurada")
                    .font(.headline)

                Text("Acesse a aba \"IA\" para configurar um provedor e ativar este recurso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }

    private var systemPromptSection: some View {
        SettingsGroup("Diretrizes do Sistema", icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Instruções Base")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Button("Restaurar Padrão") {
                        self.viewModel.resetSystemPrompt()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                TextEditor(text: self.$viewModel.settings.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var userPromptsSection: some View {
        SettingsGroup("Prompts de Processamento", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Escolha o prompt ativo para as novas transcrições.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        self.viewModel.editingPrompt = nil
                        self.viewModel.showPromptEditor = true
                    } label: {
                        Label("Novo", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                VStack(spacing: 8) {
                    ForEach(PostProcessingPrompt.allPredefined) { prompt in
                        self.promptRow(prompt: prompt, isPredefined: true)
                    }

                    if !self.viewModel.settings.userPrompts.isEmpty {
                        Divider().padding(.vertical, 8)

                        ForEach(self.viewModel.settings.userPrompts) { prompt in
                            self.promptRow(prompt: prompt, isPredefined: false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt, isPredefined: Bool) -> some View {
        let isSelected = self.viewModel.settings.selectedPromptId == prompt.id

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                    .frame(width: 36, height: 36)

                Image(systemName: prompt.icon)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.body)
                    .fontWeight(isSelected ? .bold : .medium)

                if let description = prompt.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isSelected)
            }

            if !isPredefined {
                Menu {
                    Button {
                        self.viewModel.editingPrompt = prompt
                        self.viewModel.showPromptEditor = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        self.viewModel.confirmDeletePrompt(prompt)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            self.viewModel.selectPrompt(prompt.id)
        }
    }
}

#Preview {
    PostProcessingSettingsTab()
}
