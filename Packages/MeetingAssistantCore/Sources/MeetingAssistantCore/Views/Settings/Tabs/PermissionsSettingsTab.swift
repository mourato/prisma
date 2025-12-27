import SwiftUI

// MARK: - Permissions Settings Tab

/// Tab for managing app permissions (microphone, screen recording).
public struct PermissionsSettingsTab: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                SettingsGroup(NSLocalizedString("settings.permissions.about", bundle: .safeModule, comment: ""), icon: "info.circle") {
                    Text(NSLocalizedString("settings.permissions.description", bundle: .safeModule, comment: ""))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SettingsGroup(NSLocalizedString("settings.permissions.status", bundle: .safeModule, comment: ""), icon: "checkmark.shield") {
                    let viewModel = PermissionViewModel(
                        manager: RecordingManager.shared.permissionStatus,
                        requestMicrophone: { await RecordingManager.shared.requestPermission() },
                        requestScreen: { await RecordingManager.shared.requestPermission() },
                        openMicrophoneSettings: { RecordingManager.shared.openMicrophoneSettings() },
                        openScreenSettings: { RecordingManager.shared.openPermissionSettings() }
                    )
                    PermissionStatusView(viewModel: viewModel)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .task {
            await RecordingManager.shared.checkPermission()
        }
    }
}

#Preview {
    PermissionsSettingsTab()
}
