import AppKit
import MeetingAssistantCore

@MainActor
final class ShortcutActivationState {
    private var leftCommandIsDown = false
    private var rightCommandIsDown = false
    private var leftOptionIsDown = false
    private var rightOptionIsDown = false
    private var leftShiftIsDown = false
    private var rightShiftIsDown = false
    private var leftControlIsDown = false
    private var rightControlIsDown = false
    private var fnIsDown = false

    func reset() {
        leftCommandIsDown = false
        rightCommandIsDown = false
        leftOptionIsDown = false
        rightOptionIsDown = false
        leftShiftIsDown = false
        rightShiftIsDown = false
        leftControlIsDown = false
        rightControlIsDown = false
        fnIsDown = false
    }

    func isPresetActive(_ preset: PresetShortcutKey, event: NSEvent) -> Bool {
        let flags = normalizedFlags(event.modifierFlags)
        updateTrackedModifierState(event: event, flags: flags)

        switch preset {
        case .rightCommand:
            return rightCommandIsDown && matchesModifiers(flags, required: .command)
        case .rightOption:
            return rightOptionIsDown && matchesModifiers(flags, required: .option)
        case .rightShift:
            return rightShiftIsDown && matchesModifiers(flags, required: .shift)
        case .rightControl:
            return rightControlIsDown && matchesModifiers(flags, required: .control)
        case .fn:
            return fnIsDown && matchesModifiers(flags, required: .function)
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

    func isModifierGestureActive(_ gesture: ModifierShortcutGesture, event: NSEvent) -> Bool {
        let flags = normalizedFlags(event.modifierFlags)
        updateTrackedModifierState(event: event, flags: flags)
        return matchesGesture(gesture, flags: flags)
    }

    private func updateTrackedModifierState(
        event: NSEvent,
        flags: NSEvent.ModifierFlags
    ) {
        switch event.keyCode {
        case PresetShortcutKey.leftCommandKeyCode:
            leftCommandIsDown.toggle()
        case PresetShortcutKey.rightCommandKeyCode:
            rightCommandIsDown.toggle()
        case PresetShortcutKey.leftOptionKeyCode:
            leftOptionIsDown.toggle()
        case PresetShortcutKey.rightOptionKeyCode:
            rightOptionIsDown.toggle()
        case PresetShortcutKey.leftShiftKeyCode:
            leftShiftIsDown.toggle()
        case PresetShortcutKey.rightShiftKeyCode:
            rightShiftIsDown.toggle()
        case PresetShortcutKey.leftControlKeyCode:
            leftControlIsDown.toggle()
        case PresetShortcutKey.rightControlKeyCode:
            rightControlIsDown.toggle()
        case PresetShortcutKey.fnKeyCode:
            fnIsDown.toggle()
        default:
            break
        }

        if !flags.contains(.command) {
            leftCommandIsDown = false
            rightCommandIsDown = false
        }
        if !flags.contains(.option) {
            leftOptionIsDown = false
            rightOptionIsDown = false
        }
        if !flags.contains(.shift) {
            leftShiftIsDown = false
            rightShiftIsDown = false
        }
        if !flags.contains(.control) {
            leftControlIsDown = false
            rightControlIsDown = false
        }
        if !flags.contains(.function) {
            fnIsDown = false
        }
    }

    private func matchesGesture(
        _ gesture: ModifierShortcutGesture,
        flags: NSEvent.ModifierFlags
    ) -> Bool {
        let required = Set(gesture.keys)
        guard !required.isEmpty else {
            return false
        }

        guard matchesModifierFamily(
            required: required,
            anyFlagActive: flags.contains(.command),
            leftIsDown: leftCommandIsDown,
            rightIsDown: rightCommandIsDown,
            anyKey: .command,
            leftKey: .leftCommand,
            rightKey: .rightCommand
        ) else {
            return false
        }

        guard matchesModifierFamily(
            required: required,
            anyFlagActive: flags.contains(.shift),
            leftIsDown: leftShiftIsDown,
            rightIsDown: rightShiftIsDown,
            anyKey: .shift,
            leftKey: .leftShift,
            rightKey: .rightShift
        ) else {
            return false
        }

        guard matchesModifierFamily(
            required: required,
            anyFlagActive: flags.contains(.option),
            leftIsDown: leftOptionIsDown,
            rightIsDown: rightOptionIsDown,
            anyKey: .option,
            leftKey: .leftOption,
            rightKey: .rightOption
        ) else {
            return false
        }

        guard matchesModifierFamily(
            required: required,
            anyFlagActive: flags.contains(.control),
            leftIsDown: leftControlIsDown,
            rightIsDown: rightControlIsDown,
            anyKey: .control,
            leftKey: .leftControl,
            rightKey: .rightControl
        ) else {
            return false
        }

        let requiresFn = required.contains(.fn)
        if requiresFn != fnIsDown {
            return false
        }

        return true
    }

    private func matchesModifierFamily(
        required: Set<ModifierShortcutKey>,
        anyFlagActive: Bool,
        leftIsDown: Bool,
        rightIsDown: Bool,
        anyKey: ModifierShortcutKey,
        leftKey: ModifierShortcutKey,
        rightKey: ModifierShortcutKey
    ) -> Bool {
        let requiresAny = required.contains(anyKey)
        let requiresLeft = required.contains(leftKey)
        let requiresRight = required.contains(rightKey)

        if requiresAny, !anyFlagActive {
            return false
        }
        if requiresLeft, !leftIsDown {
            return false
        }
        if requiresRight, !rightIsDown {
            return false
        }

        if !requiresAny {
            if !requiresLeft, leftIsDown {
                return false
            }
            if !requiresRight, rightIsDown {
                return false
            }
        }

        return true
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
    static let leftCommandKeyCode: UInt16 = 0x37
    static let rightCommandKeyCode: UInt16 = 0x36
    static let leftOptionKeyCode: UInt16 = 0x3a
    static let rightOptionKeyCode: UInt16 = 0x3d
    static let leftShiftKeyCode: UInt16 = 0x38
    static let rightShiftKeyCode: UInt16 = 0x3c
    static let leftControlKeyCode: UInt16 = 0x3b
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
