import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Permissions Settings Tab

/// Tab for managing app permissions (microphone, screen recording).
public struct PermissionsSettingsTab: View {
    @StateObject private var viewModel: PermissionViewModel
    @StateObject private var shortcutSettingsViewModel = ShortcutSettingsViewModel()
    @StateObject private var assistantShortcutSettingsViewModel = AssistantShortcutSettingsViewModel()

    public init() {
        let recordingManager = RecordingManager.shared
        _viewModel = StateObject(wrappedValue: PermissionViewModel(
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
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.permissions".localized,
                description: "settings.permissions.description".localized
            )

            DSGroup("settings.permissions.status".localized, icon: "checkmark.shield") {
                PermissionStatusView(viewModel: viewModel, requiredSource: .all)
                    .padding(.top, AppDesignSystem.Layout.spacing4)
            }

            if shortcutSettingsViewModel.shortcutCaptureHealthPresentation != nil ||
                assistantShortcutSettingsViewModel.shortcutCaptureHealthPresentation != nil
            {
                DSGroup("settings.shortcuts.health.title".localized, icon: "keyboard") {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Layout.spacing12) {
                        if let globalPresentation = shortcutSettingsViewModel.shortcutCaptureHealthPresentation {
                            ShortcutCaptureHealthStatusView(presentation: globalPresentation) {
                                shortcutSettingsViewModel.openShortcutCaptureHealthAction()
                            }
                        }

                        if let assistantPresentation = assistantShortcutSettingsViewModel.shortcutCaptureHealthPresentation {
                            ShortcutCaptureHealthStatusView(presentation: assistantPresentation) {
                                assistantShortcutSettingsViewModel.openShortcutCaptureHealthAction()
                            }
                        }
                    }
                }
            }

            if viewModel.allPermissionsGranted {
                SettingsStateBlock(
                    kind: .success,
                    title: "common.ok".localized,
                    message: "permissions.system_title".localized
                )
            } else {
                SettingsStateBlock(
                    kind: .warning,
                    title: "permissions.action_required".localized,
                    message: "permissions.warning".localized,
                    actionTitle: "permissions.configure".localized
                ) {
                    viewModel.openScreenSystemSettings()
                }
            }
        }
        .task {
            await RecordingManager.shared.checkPermission()
        }
    }
}

#Preview {
    PermissionsSettingsTab()
}
