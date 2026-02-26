import SwiftUI

// MARK: - Onboarding Completion View

/// The final step of the onboarding flow, congratulating the user.
public struct OnboardingCompletionView: View {
    let onStartUsing: () -> Void

    public init(onStartUsing: @escaping () -> Void) {
        self.onStartUsing = onStartUsing
    }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.green)
            }

            // Title
            Text("onboarding.completion.title".localized)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            // Subtitle
            Text("onboarding.completion.subtitle".localized)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Start Using Button
            Button(action: onStartUsing) {
                Text("onboarding.completion.button".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 350)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    OnboardingCompletionView(onStartUsing: {})
        .frame(width: 600, height: 500)
}
