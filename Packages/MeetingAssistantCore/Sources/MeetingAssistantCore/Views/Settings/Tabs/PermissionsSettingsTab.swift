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
            openScreenSettings: { recordingManager.openPermissionSettings() }
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                SettingsGroup(NSLocalizedString("settings.permissions.about", bundle: .safeModule, comment: ""), icon: "info.circle") {
                    Text(NSLocalizedString("settings.permissions.description", bundle: .safeModule, comment: ""))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SettingsGroup(NSLocalizedString("settings.permissions.status", bundle: .safeModule, comment: ""), icon: "checkmark.shield") {
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
