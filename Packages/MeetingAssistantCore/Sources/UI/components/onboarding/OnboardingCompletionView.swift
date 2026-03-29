import SwiftUI

// MARK: - Onboarding Completion View

/// The final step of the onboarding flow, congratulating the user.
public struct OnboardingCompletionView: View {
    let onStartUsing: () -> Void

    public init(onStartUsing: @escaping () -> Void) {
        self.onStartUsing = onStartUsing
    }

    public var body: some View {
        VStack(spacing: 24) {
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
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("onboarding.completion.subtitle".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Start Using Button
            Button("onboarding.completion.button".localized, action: onStartUsing)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: 350)
        }
        .padding(32)
    }
}

// MARK: - Preview

#Preview {
    OnboardingCompletionView(onStartUsing: {})
        .frame(width: 600, height: 500)
}
