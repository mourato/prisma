import SwiftUI

// MARK: - Permissions Settings Tab

/// Tab for managing app permissions (microphone, screen recording).
public struct PermissionsSettingsTab: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignSystem.Layout.sectionSpacing) {
                SettingsGroup("Sobre Permissões", icon: "info.circle") {
                    Text("O Meeting Assistant precisa de acesso ao microfone e à gravação de tela para capturar o áudio das suas reuniões e identificar os aplicativos ativos.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SettingsGroup("Status das Permissões", icon: "checkmark.shield") {
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
