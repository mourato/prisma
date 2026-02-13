import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MAModifierShortcutEditor: View {
    @Binding private var gesture: ModifierShortcutGesture?
    @Binding private var triggerMode: ModifierShortcutTriggerMode
    private let conflictMessage: String?

    @StateObject private var recorder = ModifierShortcutRecorderController()

    public init(
        gesture: Binding<ModifierShortcutGesture?>,
        triggerMode: Binding<ModifierShortcutTriggerMode>,
        conflictMessage: String?
    ) {
        _gesture = gesture
        _triggerMode = triggerMode
        self.conflictMessage = conflictMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            HStack {
                Text("settings.shortcuts.modifier.title".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(recorder.isRecording ? "settings.shortcuts.modifier.stop".localized : "settings.shortcuts.modifier.record".localized) {
                    if recorder.isRecording {
                        recorder.stopRecording(cancelled: true)
                    } else {
                        recorder.start { capturedKeys in
                            let appliedMode = gesture?.triggerMode ?? triggerMode
                            gesture = ModifierShortcutGesture(keys: capturedKeys, triggerMode: appliedMode)
                            triggerMode = appliedMode
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if gesture != nil {
                    Button("settings.shortcuts.modifier.clear".localized) {
                        recorder.stopRecording(cancelled: true)
                        gesture = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text("settings.shortcuts.modifier.description".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            ModifierShortcutChipRow(keys: gesture?.keys ?? [])

            Picker("settings.shortcuts.modifier.trigger".localized, selection: $triggerMode) {
                Text("settings.shortcuts.modifier.trigger.single_tap".localized)
                    .tag(ModifierShortcutTriggerMode.singleTap)
                Text("settings.shortcuts.activation_mode.hold".localized)
                    .tag(ModifierShortcutTriggerMode.hold)
                Text("settings.shortcuts.activation_mode.double_tap".localized)
                    .tag(ModifierShortcutTriggerMode.doubleTap)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .disabled(gesture == nil)
            .opacity(gesture == nil ? 0.6 : 1)

            if let conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            }
        }
        .onDisappear {
            recorder.stopRecording(cancelled: true)
        }
    }
}

private struct ModifierShortcutChipRow: View {
    let keys: [ModifierShortcutKey]

    var body: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
            if keys.isEmpty {
                Text("settings.shortcuts.modifier.none".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(keys, id: \.self) { key in
                    Text(key.tokenLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
                        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)
                        .background(MeetingAssistantDesignSystem.Colors.secondaryFill)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private extension ModifierShortcutKey {
    var tokenLabel: String {
        switch self {
        case .leftCommand: "L⌘"
        case .rightCommand: "R⌘"
        case .leftShift: "L⇧"
        case .rightShift: "R⇧"
        case .leftOption: "L⌥"
        case .rightOption: "R⌥"
        case .leftControl: "L⌃"
        case .rightControl: "R⌃"
        case .fn: "Fn"
        case .command: "⌘"
        case .shift: "⇧"
        case .option: "⌥"
        case .control: "⌃"
        }
    }
}

@MainActor
private final class ModifierShortcutRecorderController: ObservableObject {
    @Published private(set) var isRecording = false

    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?
    private var pressedKeys = Set<ModifierShortcutKey>()
    private var lastCapturedKeys: [ModifierShortcutKey] = []
    private var completion: (([ModifierShortcutKey]) -> Void)?

    func start(completion: @escaping ([ModifierShortcutKey]) -> Void) {
        stopRecording(cancelled: true)
        self.completion = completion
        isRecording = true
        pressedKeys.removeAll()
        lastCapturedKeys = []

        flagsMonitor = KeyboardEventMonitor(mask: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        flagsMonitor?.start()

        keyDownMonitor = KeyboardEventMonitor(mask: .keyDown, shouldReturnEvent: false) { [weak self] event in
            self?.handleKeyDown(event)
        }
        keyDownMonitor?.start()
    }

    func stopRecording(cancelled: Bool) {
        flagsMonitor?.stop()
        flagsMonitor = nil
        keyDownMonitor?.stop()
        keyDownMonitor = nil

        let keysToCommit = lastCapturedKeys
        let completionHandler = completion
        completion = nil
        pressedKeys.removeAll()
        lastCapturedKeys = []
        isRecording = false

        guard !cancelled, !keysToCommit.isEmpty else {
            return
        }

        completionHandler?(keysToCommit)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard let key = Self.modifierKey(for: event.keyCode) else {
            return
        }

        if pressedKeys.contains(key) {
            pressedKeys.remove(key)
        } else {
            pressedKeys.insert(key)
        }

        if !pressedKeys.isEmpty {
            lastCapturedKeys = pressedKeys.sorted { lhs, rhs in
                lhs.sortOrder < rhs.sortOrder
            }
        }

        if pressedKeys.isEmpty, !lastCapturedKeys.isEmpty {
            stopRecording(cancelled: false)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Escape cancels recording without changing the gesture.
        if event.keyCode == 0x35 {
            stopRecording(cancelled: true)
        }
    }

    private static func modifierKey(for keyCode: UInt16) -> ModifierShortcutKey? {
        switch keyCode {
        case 0x37: .leftCommand
        case 0x36: .rightCommand
        case 0x38: .leftShift
        case 0x3c: .rightShift
        case 0x3a: .leftOption
        case 0x3d: .rightOption
        case 0x3b: .leftControl
        case 0x3e: .rightControl
        case 0x3f: .fn
        default: nil
        }
    }
}

#Preview("Empty") {
    PreviewStateContainer(ModifierShortcutGesture?.none) { gesture in
        PreviewStateContainer(ModifierShortcutTriggerMode.singleTap) { triggerMode in
            MAModifierShortcutEditor(
                gesture: gesture,
                triggerMode: triggerMode,
                conflictMessage: nil
            )
            .padding()
            .frame(width: 520)
        }
    }
}

#Preview("Configured") {
    PreviewStateContainer(
        Optional(
            ModifierShortcutGesture(
                keys: [.rightCommand, .leftShift],
                triggerMode: .doubleTap
            )
        )
    ) { gesture in
        PreviewStateContainer(ModifierShortcutTriggerMode.doubleTap) { triggerMode in
            MAModifierShortcutEditor(
                gesture: gesture,
                triggerMode: triggerMode,
                conflictMessage: "settings.shortcuts.modifier.conflict".localized(with: "Meeting Shortcut")
            )
            .padding()
            .frame(width: 520)
        }
    }
}
