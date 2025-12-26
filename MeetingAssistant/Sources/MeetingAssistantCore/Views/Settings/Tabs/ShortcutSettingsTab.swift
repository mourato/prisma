import KeyboardShortcuts
import SwiftUI

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
public struct ShortcutSettingsTab: View {
    @StateObject private var viewModel = ShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                SettingsGroup("Atalhos Globais", icon: "command") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configure atalhos de teclado para controlar o aplicativo com agilidade, mesmo em segundo plano.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alternar Gravação")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Inicia ou encerra a gravação atual")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            KeyboardShortcuts.Recorder(for: .toggleRecording)
                        }
                    }
                }

                SettingsCard {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.secondary)

                        Button(action: {
                            self.viewModel.resetShortcuts()
                        }) {
                            Text("Resetar para atalhos padrão")
                        }
                        .buttonStyle(.link)

                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
}
