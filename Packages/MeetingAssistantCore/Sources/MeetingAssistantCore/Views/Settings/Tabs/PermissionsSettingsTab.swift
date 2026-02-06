import SwiftUI

// MARK: - Permissions Settings Tab

/// Tab for managing app permissions (microphone, screen recording).
public struct PermissionsSettingsTab: View {
    @State private var viewModel: PermissionViewModel

    public init() {
        let recordingManager = RecordingManager.shared
        _viewModel = State(initialValue: PermissionViewModel(
            manager: recordingManager.permissionStatus,
            requestMicrophone: { await recordingManager.requestPermission(for: .microphone) },
            requestScreen: { await recordingManager.requestPermission(for: .system) },
            openMicrophoneSettings: { recordingManager.openMicrophoneSettings() },
            openScreenSettings: { recordingManager.openPermissionSettings() },
            requestAccessibility: { recordingManager.requestAccessibilityPermission() },
            openAccessibilitySettings: { recordingManager.openAccessibilitySettings() }
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                SettingsGroup("settings.permissions.about".localized, icon: "info.circle") {
                    Text("settings.permissions.description".localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SettingsGroup("settings.permissions.status".localized, icon: "checkmark.shield") {
                    PermissionStatusView(viewModel: viewModel, requiredSource: .all)
                        .padding(.top, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await RecordingManager.shared.checkPermission()
        }
    }
}

#Preview {
    PermissionsSettingsTab()
}
