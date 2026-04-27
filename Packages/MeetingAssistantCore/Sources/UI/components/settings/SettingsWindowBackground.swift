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

private struct SettingsWindowVisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

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
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.isEmphasized = false
    }
}

#Preview {
    SettingsWindowBackground()
}
