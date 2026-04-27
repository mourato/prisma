import SwiftUI

public struct SettingsWindowBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            if AppDesignSystem.Accessibility.reduceTransparency {
                AppDesignSystem.Colors.settingsCanvasBackground
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)

                Rectangle()
                    .fill(AppDesignSystem.Colors.settingsGlassBackground)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SettingsWindowBackground()
}
