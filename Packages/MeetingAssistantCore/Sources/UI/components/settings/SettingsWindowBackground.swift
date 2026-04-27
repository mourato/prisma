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
        static let radialHighlightRadius: CGFloat = 160
        static let noiseStep: CGFloat = 6
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
                    .opacity(0.06)
            }

            LinearGradient(
                colors: [
                    AppDesignSystem.Colors.settingsTitleBarHighlight,
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    AppDesignSystem.Colors.settingsTitleBarHighlight.opacity(0.7),
                    .clear,
                ],
                center: UnitPoint(x: 0.18, y: 0),
                startRadius: 0,
                endRadius: Layout.radialHighlightRadius
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    .clear,
                    AppDesignSystem.Colors.settingsTitleBarShadow,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if !AppDesignSystem.Accessibility.reduceTransparency {
                SettingsTitleBarNoiseOverlay(step: Layout.noiseStep)
                    .blendMode(.overlay)
            }
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

private struct SettingsTitleBarNoiseOverlay: View {
    let step: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let columns = Int(ceil(size.width / step))
            let rows = Int(ceil(size.height / step))

            for column in 0..<columns {
                for row in 0..<rows {
                    let value = noiseValue(column: column, row: row)
                    guard value > 0.6 else { continue }

                    let alpha = (value - 0.6) * 0.14
                    let rect = CGRect(
                        x: CGFloat(column) * step,
                        y: CGFloat(row) * step,
                        width: 1,
                        height: 1
                    )

                    context.fill(
                        Path(rect),
                        with: .color(AppDesignSystem.Colors.settingsTitleBarNoise.opacity(alpha))
                    )
                }
            }
        }
    }

    private func noiseValue(column: Int, row: Int) -> Double {
        let hash = (column &* 73_856_093) ^ (row &* 19_349_663)
        return Double(abs(hash % 1_000)) / 1_000
    }
}

#Preview {
    SettingsWindowBackground()
}

#Preview("Title Bar Material") {
    SettingsTitleBarMaterialBackground()
        .frame(width: 900, height: AppDesignSystem.Layout.settingsTitleBarMaterialHeight)
}
