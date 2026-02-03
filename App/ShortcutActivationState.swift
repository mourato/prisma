import AppKit
import MeetingAssistantCore

@MainActor
final class ShortcutActivationState {
    private var rightCommandIsDown = false
    private var rightOptionIsDown = false
    private var rightShiftIsDown = false
    private var rightControlIsDown = false
    private var fnIsDown = false

    func reset() {
        rightCommandIsDown = false
        rightOptionIsDown = false
        rightShiftIsDown = false
        rightControlIsDown = false
        fnIsDown = false
    }

    func isPresetActive(_ preset: PresetShortcutKey, event: NSEvent) -> Bool {
        let flags = normalizedFlags(event.modifierFlags)

        switch preset {
        case .rightCommand:
            return updateRightModifierState(
                event: event,
                keyCode: PresetShortcutKey.rightCommandKeyCode,
                required: .command,
                state: &rightCommandIsDown,
                flags: flags
            )
        case .rightOption:
            return updateRightModifierState(
                event: event,
                keyCode: PresetShortcutKey.rightOptionKeyCode,
                required: .option,
                state: &rightOptionIsDown,
                flags: flags
            )
        case .rightShift:
            return updateRightModifierState(
                event: event,
                keyCode: PresetShortcutKey.rightShiftKeyCode,
                required: .shift,
                state: &rightShiftIsDown,
                flags: flags
            )
        case .rightControl:
            return updateRightModifierState(
                event: event,
                keyCode: PresetShortcutKey.rightControlKeyCode,
                required: .control,
                state: &rightControlIsDown,
                flags: flags
            )
        case .fn:
            return updateRightModifierState(
                event: event,
                keyCode: PresetShortcutKey.fnKeyCode,
                required: .function,
                state: &fnIsDown,
                flags: flags
            )
        case .optionCommand:
            return matchesModifiers(flags, required: [.option, .command])
        case .controlCommand:
            return matchesModifiers(flags, required: [.control, .command])
        case .controlOption:
            return matchesModifiers(flags, required: [.control, .option])
        case .shiftCommand:
            return matchesModifiers(flags, required: [.shift, .command])
        case .optionShift:
            return matchesModifiers(flags, required: [.option, .shift])
        case .controlShift:
            return matchesModifiers(flags, required: [.control, .shift])
        case .notSpecified, .custom:
            return false
        }
    }

    private func updateRightModifierState(
        event: NSEvent,
        keyCode: UInt16,
        required: NSEvent.ModifierFlags,
        state: inout Bool,
        flags: NSEvent.ModifierFlags
    ) -> Bool {
        if event.keyCode == keyCode {
            state = flags.contains(required)
        }

        return state && matchesModifiers(flags, required: required)
    }

    private func matchesModifiers(
        _ flags: NSEvent.ModifierFlags,
        required: NSEvent.ModifierFlags
    ) -> Bool {
        guard flags.contains(required) else {
            return false
        }

        let extras = flags.subtracting(required)
        return extras.isEmpty
    }

    private func normalizedFlags(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
    }
}

extension PresetShortcutKey {
    static let rightCommandKeyCode: UInt16 = 0x36
    static let rightOptionKeyCode: UInt16 = 0x3d
    static let rightShiftKeyCode: UInt16 = 0x3c
    static let rightControlKeyCode: UInt16 = 0x3e
    static let fnKeyCode: UInt16 = 0x3f
    static let escapeKeyCode: UInt16 = 0x35

    var requiresModifierMonitoring: Bool {
        switch self {
        case .notSpecified, .custom:
            false
        case .rightCommand, .rightOption, .rightShift, .rightControl, .fn:
            true
        case .optionCommand, .controlCommand, .controlOption, .shiftCommand, .optionShift, .controlShift:
            true
        }
    }
}
