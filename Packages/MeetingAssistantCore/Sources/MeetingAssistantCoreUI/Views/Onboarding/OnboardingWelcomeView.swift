import SwiftUI

// MARK: - Onboarding Welcome View

/// The first step of the onboarding flow, welcoming the user.
public struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void

    public init(onGetStarted: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
    }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App Icon
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)

            // Title
            Text("onboarding.welcome.title".localized)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            // Subtitle
            Text("onboarding.welcome.subtitle".localized)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Get Started Button
            Button(action: onGetStarted) {
                Text("onboarding.welcome.button".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 300)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    OnboardingWelcomeView(onGetStarted: {})
        .frame(width: 600, height: 500)
}
