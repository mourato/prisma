import SwiftUI

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
public struct ShortcutSettingsTab: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Atalho Global para Gravação") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pressione este atalho em qualquer lugar do sistema para iniciar ou parar a gravação.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        shortcutDisplay
                        
                        Spacer()
                        
                        recordButton
                    }
                    
                    if shortcutManager.isRegistered {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Atalho registrado e ativo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Instruções") {
                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(
                        icon: "1.circle.fill",
                        text: "Clique em \"Gravar Atalho\" para definir um novo atalho"
                    )
                    instructionRow(
                        icon: "2.circle.fill",
                        text: "Pressione a combinação de teclas desejada"
                    )
                    instructionRow(
                        icon: "3.circle.fill",
                        text: "O atalho deve incluir pelo menos uma tecla modificadora (⌘, ⌥, ⌃, ⇧)"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Section {
                Button("Restaurar Padrão (⌘⇧R)") {
                    settings.keyboardShortcut = .default
                }
                .buttonStyle(.link)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var shortcutDisplay: some View {
        HStack {
            if shortcutManager.isRecordingShortcut {
                Text("Pressione as teclas...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.orange, lineWidth: 2)
                    )
            } else {
                Text(settings.keyboardShortcut.displayString)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var recordButton: some View {
        if shortcutManager.isRecordingShortcut {
            Button("Cancelar") {
                shortcutManager.stopRecordingShortcut()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button("Gravar Atalho") {
                shortcutManager.onShortcutCaptured = { newShortcut in
                    settings.keyboardShortcut = newShortcut
                }
                shortcutManager.startRecordingShortcut()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
        }
    }
}

#Preview {
    ShortcutSettingsTab()
}
