import AppKit
import MeetingAssistantCore

extension ShortcutInputEvent {
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
    }
}
