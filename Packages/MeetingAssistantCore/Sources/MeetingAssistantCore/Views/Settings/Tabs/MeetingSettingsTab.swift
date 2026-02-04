import KeyboardShortcuts
import SwiftUI

// MARK: - Meeting Settings Tab

/// Tab for meeting-specific settings like app monitoring and automation.
public struct MeetingSettingsTab: View {
    @StateObject private var viewModel = GeneralSettingsViewModel()
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                // Automation
                SettingsGroup("settings.meetings.workflow".localized, icon: "bolt.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggle(
                            "settings.general.auto_start".localized,
                            isOn: $viewModel.autoStartRecording
                        )

                        Divider()

                        SettingsToggle(
                            "settings.general.merge_audio".localized,
                            isOn: $viewModel.shouldMergeAudioFiles
                        )
                    }
                }

                // Keyboard Shortcut
                SettingsGroup("settings.shortcuts.meeting".localized, icon: "keyboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.shortcuts.meeting_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.shortcuts.meeting".localized)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Picker("", selection: $shortcutsViewModel.meetingSelectedPresetKey) {
                                ForEach(PresetShortcutKey.allCases, id: \.self) { key in
                                    if let icon = key.icon {
                                        Label(key.displayName, systemImage: icon).tag(key)
                                    } else {
                                        Text(key.displayName).tag(key)
                                    }
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }

                        if shortcutsViewModel.meetingSelectedPresetKey == .custom {
                            Divider()

                            HStack {
                                Text("settings.shortcuts.custom_shortcut".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                KeyboardShortcuts.Recorder(for: .meetingToggle)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Apps
                SettingsGroup("settings.general.monitored_apps".localized, icon: "app.badge") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.general.monitored_apps_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        ForEach(MeetingApp.allCases, id: \.self) { app in
                            HStack(spacing: 12) {
                                Image(systemName: app.icon)
                                    .font(.title3)
                                    .foregroundStyle(app.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("settings.general.monitoring_active".localized)
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }

                                Spacer()
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    MeetingSettingsTab()
}
