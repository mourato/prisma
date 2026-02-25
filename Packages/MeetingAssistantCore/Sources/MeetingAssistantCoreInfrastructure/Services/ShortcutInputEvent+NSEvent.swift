import AppKit
import Foundation

public extension ShortcutInputEvent {
    init(systemEvent: NSEvent) {
        let kind: ShortcutInputEventKind
        switch systemEvent.type {
        case .flagsChanged:
            kind = .flagsChanged
        case .keyDown:
            kind = .keyDown
        case .keyUp:
            kind = .keyUp
        default:
            kind = .keyDown
        }

        self.init(
            kind: kind,
            keyCode: systemEvent.keyCode,
            modifierFlagsRawValue: systemEvent.modifierFlags.rawValue,
            isRepeat: systemEvent.isARepeat,
            charactersIgnoringModifiers: systemEvent.charactersIgnoringModifiers
        )
    }
}
