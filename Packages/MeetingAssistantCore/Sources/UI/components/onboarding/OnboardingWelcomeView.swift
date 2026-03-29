import SwiftUI

// MARK: - Onboarding Welcome View

/// The first step of the onboarding flow, welcoming the user.
public struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void

    public init(onGetStarted: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
    }

    public var body: some View {
        VStack(spacing: 24) {
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
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("onboarding.welcome.subtitle".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Get Started Button
            Button("onboarding.welcome.button".localized, action: onGetStarted)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: 300)
        }
        .padding(32)
    }
}

// MARK: - Preview

#Preview {
    OnboardingWelcomeView(onGetStarted: {})
        .frame(width: 600, height: 500)
}
