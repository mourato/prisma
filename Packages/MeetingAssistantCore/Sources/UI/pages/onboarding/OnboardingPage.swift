import AppKit
import Combine
import MeetingAssistantCoreAI
import SwiftUI

// MARK: - Onboarding View

/// Main container view that orchestrates all onboarding steps.
public struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var permissionViewModel: PermissionViewModel
    @ObservedObject var shortcutViewModel: ShortcutSettingsViewModel
    @ObservedObject var assistantShortcutViewModel: AssistantShortcutSettingsViewModel
    @ObservedObject var modelManager: FluidAIModelManager

    let onComplete: () -> Void
    let refreshPermissions: @MainActor () async -> Void

    public init(
        viewModel: OnboardingViewModel,
        permissionViewModel: PermissionViewModel,
        shortcutViewModel: ShortcutSettingsViewModel,
        assistantShortcutViewModel: AssistantShortcutSettingsViewModel,
        modelManager: FluidAIModelManager,
        refreshPermissions: @escaping @MainActor () async -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.permissionViewModel = permissionViewModel
        self.shortcutViewModel = shortcutViewModel
        self.assistantShortcutViewModel = assistantShortcutViewModel
        self.modelManager = modelManager
        self.refreshPermissions = refreshPermissions
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Step Indicator
            OnboardingStepIndicator(
                currentStep: viewModel.currentStep,
                totalSteps: OnboardingStep.allCases.count
            )
            .padding(.top, 20)

            // Content Area
            contentView
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(width: 650, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.currentStep {
        case .welcome:
            OnboardingWelcomeView(onGetStarted: viewModel.goToNextStep)

        case .permissions:
            OnboardingPermissionsView(
                viewModel: permissionViewModel,
                onContinue: viewModel.goToNextStep,
                onSkip: viewModel.currentStep.isSkippable ? { viewModel.skipCurrentStep() } : nil,
                refreshAction: refreshPermissions
            )

        case .shortcuts:
            OnboardingShortcutsView(
                viewModel: shortcutViewModel,
                assistantViewModel: assistantShortcutViewModel,
                onContinue: viewModel.goToNextStep,
                onSkip: viewModel.currentStep.isSkippable ? { viewModel.skipCurrentStep() } : nil
            )

        case .downloadModels:
            OnboardingDownloadModelsView(
                modelManager: modelManager,
                onContinue: viewModel.goToNextStep,
                onSkip: viewModel.currentStep.isSkippable ? { viewModel.skipCurrentStep() } : nil
            )

        case .completion:
            OnboardingCompletionView(onStartUsing: {
                viewModel.completeOnboarding()
                onComplete()
            })
        }
    }
}

@MainActor
private func makeOnboardingViewModel(step: OnboardingStep) -> OnboardingViewModel {
    let viewModel = OnboardingViewModel()
    viewModel.currentStep = step
    return viewModel
}

@MainActor
private func makePermissionViewModel() -> PermissionViewModel {
    PermissionViewModel(
        manager: PermissionStatusManager(),
        requestMicrophone: {},
        requestScreen: {},
        openMicrophoneSettings: {},
        openScreenSettings: {},
        requestAccessibility: {},
        openAccessibilitySettings: {}
    )
}

#Preview("Onboarding - Welcome") {
    OnboardingView(
        viewModel: makeOnboardingViewModel(step: .welcome),
        permissionViewModel: makePermissionViewModel(),
        shortcutViewModel: ShortcutSettingsViewModel(),
        assistantShortcutViewModel: AssistantShortcutSettingsViewModel(),
        modelManager: FluidAIModelManager.shared,
        refreshPermissions: {},
        onComplete: {}
    )
    .frame(width: 650, height: 550)
}

#Preview("Onboarding - Permissions") {
    OnboardingView(
        viewModel: makeOnboardingViewModel(step: .permissions),
        permissionViewModel: makePermissionViewModel(),
        shortcutViewModel: ShortcutSettingsViewModel(),
        assistantShortcutViewModel: AssistantShortcutSettingsViewModel(),
        modelManager: FluidAIModelManager.shared,
        refreshPermissions: {},
        onComplete: {}
    )
    .frame(width: 650, height: 550)
}

#Preview("Onboarding - Shortcuts") {
    OnboardingView(
        viewModel: makeOnboardingViewModel(step: .shortcuts),
        permissionViewModel: makePermissionViewModel(),
        shortcutViewModel: ShortcutSettingsViewModel(),
        assistantShortcutViewModel: AssistantShortcutSettingsViewModel(),
        modelManager: FluidAIModelManager.shared,
        refreshPermissions: {},
        onComplete: {}
    )
    .frame(width: 650, height: 550)
}
