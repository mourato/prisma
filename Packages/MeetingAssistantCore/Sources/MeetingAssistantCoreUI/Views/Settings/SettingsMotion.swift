import SwiftUI

enum SettingsMotion {
    static let sectionDuration: Double = 0.18
    static let sectionAnimation: Animation = .easeInOut(duration: sectionDuration)

    static func sectionTransition(reduceMotion: Bool = false) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    static func sectionAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : sectionAnimation
    }
}

extension Binding {
    func animated(using animation: Animation = SettingsMotion.sectionAnimation) -> Binding<Value> {
        transaction(Transaction(animation: animation))
    }
}

extension View {
    @ViewBuilder
    func settingsAnimated(
        reduceMotion: Bool,
        animation: Animation = SettingsMotion.sectionAnimation,
        value: some Equatable
    ) -> some View {
        if reduceMotion {
            self
        } else {
            self.animation(animation, value: value)
        }
    }

    @ViewBuilder
    func settingsPulseSymbolEffect(
        value: some Equatable,
        reduceMotion: Bool,
        options: SymbolEffectOptions = .repeating
    ) -> some View {
        if reduceMotion {
            self
        } else {
            symbolEffect(.pulse, options: options, value: value)
        }
    }

    @ViewBuilder
    func settingsPulseSymbolEffect(
        isActive: Bool,
        reduceMotion: Bool
    ) -> some View {
        if reduceMotion {
            self
        } else {
            symbolEffect(.pulse, isActive: isActive)
        }
    }
}
