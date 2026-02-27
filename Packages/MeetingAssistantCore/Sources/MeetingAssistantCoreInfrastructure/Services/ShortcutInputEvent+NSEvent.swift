import AppKit
import Foundation

public extension ShortcutInputEvent {
    init(systemEvent: NSEvent) {
        let kind: ShortcutInputEventKind = switch systemEvent.type {
        case .flagsChanged:
            .flagsChanged
        case .keyDown:
            .keyDown
        case .keyUp:
            .keyUp
        default:
            .keyDown
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
