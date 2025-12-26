import SwiftUI

// MARK: - Permissions Settings Tab

/// Tab for managing app permissions (microphone, screen recording).
public struct PermissionsSettingsTab: View {
    public init() {}

    public var body: some View {
        Form {
            Section {
                Text(
                    "O Meeting Assistant precisa de acesso ao microfone e à gravação de tela para capturar o áudio das suas reuniões."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            } header: {
                Label("Sobre Permissões", systemImage: "info.circle")
            }

            Section {
                let viewModel = PermissionViewModel(
                    manager: RecordingManager.shared.permissionStatus,
                    requestMicrophone: { await RecordingManager.shared.requestPermission() },
                    requestScreen: { await RecordingManager.shared.requestPermission() },
                    openMicrophoneSettings: { RecordingManager.shared.openMicrophoneSettings() },
                    openScreenSettings: { RecordingManager.shared.openPermissionSettings() }
                )
                PermissionStatusView(viewModel: viewModel)
            } header: {
                Label("Status das Permissões", systemImage: "checkmark.shield")
            }
        }
        .padding()
        .task {
            await RecordingManager.shared.checkPermission()
        }
    }
}

#Preview {
    PermissionsSettingsTab()
}
