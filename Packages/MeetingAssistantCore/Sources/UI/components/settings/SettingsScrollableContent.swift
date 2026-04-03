import SwiftUI

private enum SettingsScrollableContentLayout {
    static let topFadeHeight: CGFloat = 34
    static let fadeActivationThreshold: CGFloat = 2
}

private enum SettingsScrollableContentScrollTracking {
    static let coordinateSpaceName = "settingsScrollableContent"
}

public struct SettingsScrollableContent<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @State private var topOffset: CGFloat = 0

    public init(
        spacing: CGFloat = AppDesignSystem.Layout.sectionSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SettingsScrollableContentTopOffsetKey.self,
                        value: proxy.frame(in: .named(SettingsScrollableContentScrollTracking.coordinateSpaceName)).minY
                    )
                }
            }
        }
        .coordinateSpace(name: SettingsScrollableContentScrollTracking.coordinateSpaceName)
        .onPreferenceChange(SettingsScrollableContentTopOffsetKey.self) { value in
            guard abs(topOffset - value) > 0.5 else { return }
            DispatchQueue.main.async {
                topOffset = value
            }
        }
        .overlay(alignment: .top) {
            if shouldShowTopFade {
                topFadeOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: shouldShowTopFade)
    }

    private var shouldShowTopFade: Bool {
        topOffset < -SettingsScrollableContentLayout.fadeActivationThreshold
    }

    private var topFadeOverlay: some View {
        LinearGradient(
            colors: [
                AppDesignSystem.Colors.settingsTopFadeLeading,
                AppDesignSystem.Colors.settingsGlassBackground,
                AppDesignSystem.Colors.settingsTopFadeTrailing,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .background(AppDesignSystem.Colors.settingsGlassBackground)
        .frame(height: SettingsScrollableContentLayout.topFadeHeight)
        .allowsHitTesting(false)
    }
}

private struct SettingsScrollableContentTopOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    SettingsScrollableContent {
        Text("Preview")
    }
}
