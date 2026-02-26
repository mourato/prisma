import MeetingAssistantCoreDomain
import SwiftUI

// MARK: - Onboarding Permissions View

/// Second step of onboarding - requesting system permissions.
public struct OnboardingPermissionsView: View {
    @ObservedObject var viewModel: PermissionViewModel
    let onContinue: () -> Void
    let onSkip: (() -> Void)?

    public init(
        viewModel: PermissionViewModel,
        onContinue: @escaping () -> Void,
        onSkip: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onContinue = onContinue
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("onboarding.permissions.title".localized)
                    .font(.system(size: 28, weight: .bold))

                Text("onboarding.permissions.subtitle".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)

            // Permission List
            VStack(spacing: 12) {
                ForEach(OnboardingPermissionItem.allPermissions, id: \.type) { item in
                    OnboardingPermissionRow(
                        item: item,
                        status: permissionStatus(for: item.type),
                        onGrant: { requestPermission(for: item.type) },
                        onOpenSettings: { openSystemSettings(for: item.type) }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Navigation Buttons
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("onboarding.continue".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.allPermissionsGranted ? Color.accentColor : Color.secondary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 300)
                .disabled(!viewModel.allPermissionsGranted)

                if onSkip != nil {
                    Button(action: { onSkip?() }) {
                        Text("onboarding.skip".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 550)
    }

    // MARK: - Private Helpers

    private func permissionStatus(for type: OnboardingPermissionType) -> PermissionState {
        switch type {
        case .microphone: viewModel.microphoneState
        case .screenRecording: viewModel.screenState
        case .accessibility: viewModel.accessibilityState
        }
    }

    private func requestPermission(for type: OnboardingPermissionType) {
        Task {
            switch type {
            case .microphone:
                await viewModel.requestMicrophonePermission()
            case .screenRecording:
                await viewModel.requestScreenPermission()
            case .accessibility:
                viewModel.requestAccessibilityPermission()
            }
        }
    }

    private func openSystemSettings(for type: OnboardingPermissionType) {
        switch type {
        case .microphone:
            viewModel.openMicrophoneSystemSettings()
        case .screenRecording:
            viewModel.openScreenSystemSettings()
        case .accessibility:
            viewModel.openAccessibilitySystemSettings()
        }
    }
}

// MARK: - Preview

#Preview {
    let mockManager = PermissionStatusManager()
    let viewModel = PermissionViewModel(
        manager: mockManager,
        requestMicrophone: {},
        requestScreen: {},
        openMicrophoneSettings: {},
        openScreenSettings: {},
        requestAccessibility: {},
        openAccessibilitySettings: {}
    )

    OnboardingPermissionsView(
        viewModel: viewModel,
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 600, height: 550)
}
