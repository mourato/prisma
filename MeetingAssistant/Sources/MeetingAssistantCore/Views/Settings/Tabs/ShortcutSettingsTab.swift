import KeyboardShortcuts
import SwiftUI

// MARK: - Shortcut Settings Tab

/// Tab for configuring global keyboard shortcuts.
public struct ShortcutSettingsTab: View {
    public init() {}

    public var body: some View {

        Form {
            Section(header: Text("shortcut.global.title", bundle: .module)) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("shortcut.global.description", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("shortcut.action.toggleRecording", bundle: .module)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }
                }
            }

            Section {
                Button(action: {
                    KeyboardShortcuts.reset(.toggleRecording)
                }) {
                    Text("shortcut.reset.default", bundle: .module)
                }
                .buttonStyle(.link)
            }
        }
        .padding()
    }
}
