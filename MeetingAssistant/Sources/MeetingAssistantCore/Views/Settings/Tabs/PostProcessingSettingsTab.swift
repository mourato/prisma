import SwiftUI
import os.log

// MARK: - Post-Processing Settings Tab

/// Settings tab for configuring AI post-processing prompts.
public struct PostProcessingSettingsTab: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @State private var isEditingSystemPrompt = false
    @State private var editedSystemPrompt = ""
    @State private var showPromptEditor = false
    @State private var editingPrompt: PostProcessingPrompt?
    @State private var showDeleteConfirmation = false
    @State private var promptToDelete: PostProcessingPrompt?
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "PostProcessing")
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                enableToggleSection
                
                if settings.postProcessingEnabled {
                    if settings.aiConfiguration.isValid {
                        systemPromptSection
                        Divider()
                        userPromptsSection
                    } else {
                        connectionWarningSection
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showPromptEditor) {
            PromptEditorSheet(
                prompt: editingPrompt,
                onSave: handleSavePrompt,
                onCancel: { showPromptEditor = false }
            )
        }
        .alert("Excluir Prompt?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                if let prompt = promptToDelete {
                    settings.deletePrompt(id: prompt.id)
                }
            }
        } message: {
            if let prompt = promptToDelete {
                Text("Tem certeza que deseja excluir o prompt \"\(prompt.title)\"? Esta ação não pode ser desfeita.")
            }
        }
    }
    
    // MARK: - Enable Toggle Section
    
    private var enableToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Habilitar Pós-Processamento", isOn: $settings.postProcessingEnabled)
                .font(.headline)
            
            Text("Quando habilitado, as transcrições serão processadas por IA usando os prompts configurados abaixo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Connection Warning Section
    
    private var connectionWarningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Conexão com IA não configurada")
                    .font(.headline)
                
                Text("Configure um provedor de IA na aba \"IA\" para usar o pós-processamento.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - System Prompt Section
    
    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Prompt do Sistema", systemImage: "terminal.fill")
                    .font(.headline)
                
                Spacer()
                
                Button("Restaurar Padrão") {
                    settings.resetSystemPrompt()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            
            Text("Define as instruções base que serão enviadas ao modelo de IA.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $settings.systemPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150, maxHeight: 200)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        }
    }
    
    // MARK: - User Prompts Section
    
    private var userPromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Prompts de Processamento", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    editingPrompt = nil
                    showPromptEditor = true
                } label: {
                    Label("Novo Prompt", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Text("Selecione um prompt para ser usado no pós-processamento das transcrições.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Predefined prompts
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompts Pré-definidos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ForEach(PostProcessingPrompt.allPredefined) { prompt in
                    promptRow(prompt: prompt, isPredefined: true)
                }
            }
            
            // User prompts
            if !settings.userPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meus Prompts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(settings.userPrompts) { prompt in
                        promptRow(prompt: prompt, isPredefined: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Prompt Row
    
    private func promptRow(prompt: PostProcessingPrompt, isPredefined: Bool) -> some View {
        let isSelected = settings.selectedPromptId == prompt.id
        
        return HStack(spacing: 12) {
            Image(systemName: prompt.icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if let description = prompt.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !isPredefined {
                Button {
                    editingPrompt = prompt
                    showPromptEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Editar prompt")
                
                Button {
                    promptToDelete = prompt
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Excluir prompt")
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if settings.selectedPromptId == prompt.id {
                    settings.selectedPromptId = nil
                } else {
                    settings.selectedPromptId = prompt.id
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSavePrompt(_ prompt: PostProcessingPrompt) {
        if editingPrompt != nil {
            settings.updatePrompt(prompt)
        } else {
            settings.addPrompt(prompt)
        }
        showPromptEditor = false
    }
}

// MARK: - Preview

#Preview {
    PostProcessingSettingsTab()
        .frame(width: 500, height: 600)
}
