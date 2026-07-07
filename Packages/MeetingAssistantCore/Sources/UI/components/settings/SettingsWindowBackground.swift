import AppKit
import SwiftUI

public struct SettingsWindowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        nativeWindowBackground
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var nativeWindowBackground: some View {
        switch colorScheme {
        case .light, .dark:
            if AppDesignSystem.Accessibility.reduceTransparency {
                AppDesignSystem.Colors.windowBackground
            } else {
                ZStack {
                    VisualEffectView(
                        material: .sidebar,
                        blendingMode: .withinWindow
                    )
                    AppDesignSystem.Colors.windowBackground.opacity(0.50)
                }
            }
        @unknown default:
            AppDesignSystem.Colors.windowBackground
        }
    }
}

public struct SettingsTitleBarMaterialBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init(usesBottomFade: Bool = true) {
        _ = usesBottomFade
    }

    public var body: some View {
        nativeTitleBarBackground
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppDesignSystem.Colors.separator)
                    .frame(height: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var nativeTitleBarBackground: some View {
        switch colorScheme {
        case .light, .dark:
            Rectangle()
                .fill(.bar)
                .background(.bar)
        @unknown default:
            Rectangle()
                .fill(AppDesignSystem.Colors.windowBackground)
        }
    }
}

#Preview {
    SettingsWindowBackground()
}

#Preview("Title Bar Material") {
    SettingsTitleBarMaterialBackground()
        .frame(width: 900, height: AppDesignSystem.Layout.settingsTitleBarMaterialHeight)
}
