import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Onboarding Shortcuts View

/// Third step of onboarding - configuring keyboard shortcuts.
public struct OnboardingShortcutsView: View {
    @ObservedObject var viewModel: ShortcutSettingsViewModel
    let onContinue: () -> Void
    let onSkip: (() -> Void)?

    public init(
        viewModel: ShortcutSettingsViewModel,
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
                Image(systemName: "keyboard")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("onboarding.shortcuts.title".localized)
                    .font(.system(size: 28, weight: .bold))

                Text("onboarding.shortcuts.subtitle".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)

            // Shortcuts List
            VStack(spacing: 16) {
                ForEach(OnboardingShortcutItem.allShortcuts, id: \.type) { item in
                    OnboardingShortcutRow(
                        item: item,
                        viewModel: viewModel
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Navigation Buttons
            HStack(spacing: 16) {
                // Skip button (left)
                if onSkip != nil {
                    Button(action: { onSkip?() }) {
                        Text("onboarding.skip".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                // Continue button (right)
                Button(action: onContinue) {
                    Text("onboarding.continue".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 400)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 550)
    }
}

// MARK: - Onboarding Shortcut Row

private struct OnboardingShortcutRow: View {
    let item: OnboardingShortcutItem
    @ObservedObject var viewModel: ShortcutSettingsViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: iconName(for: item.type))
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                )

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text(item.titleKey.localized)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("onboarding.shortcuts.use_default".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Use Default Button
            Button(action: useDefaultShortcut) {
                Text("onboarding.shortcuts.use_default".localized)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func iconName(for type: OnboardingShortcutType) -> String {
        switch type {
        case .dictation: "text.bubble"
        case .meeting: "video"
        case .assistant: "wand.and.stars"
        }
    }

    private func useDefaultShortcut() {
        switch item.type {
        case .dictation:
            viewModel.dictationShortcutDefinition = AppSettingsStore.defaultDictationShortcutDefinition
        case .meeting:
            viewModel.meetingShortcutDefinition = AppSettingsStore.defaultMeetingShortcutDefinition
        case .assistant:
            // Assistant shortcut is handled separately in AssistantShortcutSettingsViewModel
            break
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingShortcutsView(
        viewModel: ShortcutSettingsViewModel(),
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 600, height: 550)
}
