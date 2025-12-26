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
                SettingsGroup(NSLocalizedString("settings.shortcuts.global", comment: ""), icon: "command") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("settings.shortcuts.description", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("settings.shortcuts.toggle_recording", comment: ""))
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(NSLocalizedString("settings.shortcuts.toggle_recording_desc", comment: ""))
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
                            Text(NSLocalizedString("settings.shortcuts.reset", comment: ""))
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
