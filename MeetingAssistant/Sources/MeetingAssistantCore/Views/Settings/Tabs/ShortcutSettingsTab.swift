import KeyboardShortcuts
import SwiftUI

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
public struct ShortcutSettingsTab: View {
    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("shortcut.global.title")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("shortcut.global.description")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("shortcut.action.toggleRecording")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }
                }
            }

            Section {
                Button(action: {
                    KeyboardShortcuts.reset(.toggleRecording)
                }) {
                    Text("shortcut.reset.default")
                }
                .buttonStyle(.link)
            }
        }
        .padding()
    }
}
