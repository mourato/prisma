import AppKit
import Combine
import SwiftUI

// MARK: - Onboarding View

/// Main container view that orchestrates all onboarding steps.
public struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var permissionViewModel: PermissionViewModel
    @ObservedObject var shortcutViewModel: ShortcutSettingsViewModel

    let onComplete: () -> Void

    public init(
        viewModel: OnboardingViewModel,
        permissionViewModel: PermissionViewModel,
        shortcutViewModel: ShortcutSettingsViewModel,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.permissionViewModel = permissionViewModel
        self.shortcutViewModel = shortcutViewModel
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
                onSkip: viewModel.currentStep.isSkippable ? { viewModel.skipCurrentStep() } : nil
            )

        case .shortcuts:
            OnboardingShortcutsView(
                viewModel: shortcutViewModel,
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
