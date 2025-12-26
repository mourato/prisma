import KeyboardShortcuts
import SwiftUI

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
public struct ShortcutSettingsTab: View {
    public init() {}

    public var body: some View {
        Form {
            Section("Atalho Global para Gravação") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Pressione este atalho em qualquer lugar do sistema para iniciar ou parar a gravação."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack {
                        Text("Iniciar/Parar Gravação:")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }
                }
            }

            Section {
                Button("Restaurar Padrão") {
                    KeyboardShortcuts.reset(.toggleRecording)
                }
                .buttonStyle(.link)
            }
        }
        .padding()
    }
}
