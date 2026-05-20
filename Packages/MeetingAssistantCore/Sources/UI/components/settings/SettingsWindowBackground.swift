import AppKit
import SwiftUI

public struct SettingsWindowBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            if AppDesignSystem.Accessibility.reduceTransparency {
                AppDesignSystem.Colors.settingsCanvasBackground
            } else {
                SettingsWindowVisualEffectBackground(material: .underWindowBackground)

                Rectangle()
                    .fill(AppDesignSystem.Colors.settingsGlassBackground)
            }
        }
        .ignoresSafeArea()
    }
}

public struct SettingsTitleBarMaterialBackground: View {
    private enum Layout {
        static let fadeStart: CGFloat = 0.9
    }

    private let usesBottomFade: Bool

    public init(usesBottomFade: Bool = true) {
        self.usesBottomFade = usesBottomFade
    }

    public var body: some View {
        ZStack {
            if AppDesignSystem.Accessibility.reduceTransparency {
                AppDesignSystem.Colors.settingsTitleBarTint
            } else {
                SettingsWindowVisualEffectBackground(
                    material: .titlebar,
                    blendingMode: .withinWindow
                )

                Rectangle()
                    .fill(AppDesignSystem.Colors.settingsTitleBarTint)
                    .opacity(0.04)
            }

            LinearGradient(
                colors: [
                    AppDesignSystem.Colors.settingsTitleBarHighlight,
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .clear,
                    AppDesignSystem.Colors.settingsTitleBarShadow,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppDesignSystem.Colors.settingsTitleBarDivider)
                .frame(height: 1)
        }
        .mask {
            if usesBottomFade {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: Layout.fadeStart),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.white
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SettingsWindowVisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        view.isEmphasized = false
    }
}

#Preview {
    SettingsWindowBackground()
}

#Preview("Title Bar Material") {
    SettingsTitleBarMaterialBackground()
        .frame(width: 900, height: AppDesignSystem.Layout.settingsTitleBarMaterialHeight)
}
