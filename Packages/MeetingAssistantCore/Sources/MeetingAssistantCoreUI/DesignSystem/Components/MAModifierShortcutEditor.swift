import AppKit
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
    @State private var isPopoverPresented = false
    @State private var localStatus: RecordingStatus = .idle
    @State private var localConflictMessage: String?
    @State private var attemptedKeys: [ModifierShortcutKey]?
    @State private var closeTask: Task<Void, Never>?
    @State private var restartTask: Task<Void, Never>?

    private enum RecordingStatus {
        case idle
        case recording
        case success
        case failure
    }

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
            Text("settings.shortcuts.modifier.title".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Button {
                openRecordingPopover()
            } label: {
                shortcutInputField
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                recordingPopover
                    .frame(width: 360)
                    .padding(MeetingAssistantDesignSystem.Layout.spacing12)
            }

            if let conflict = conflictMessage, !isPopoverPresented {
                Text(conflict)
                    .font(.caption)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            }

            Picker("settings.shortcuts.modifier.trigger".localized, selection: $triggerMode) {
                Text("settings.shortcuts.activation_mode.hold".localized)
                    .tag(ModifierShortcutTriggerMode.hold)
                Text("settings.shortcuts.activation_mode.double_tap".localized)
                    .tag(ModifierShortcutTriggerMode.doubleTap)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .disabled(gesture == nil)
            .opacity(gesture == nil ? 0.6 : 1)
        }
        .onChange(of: conflictMessage) { _, newValue in
            guard isPopoverPresented, attemptedKeys != nil else {
                return
            }

            if let newValue {
                localStatus = .failure
                localConflictMessage = newValue
                scheduleRecordingRestart()
            }
        }
        .onChange(of: recorder.currentKeys) { _, newValue in
            guard !newValue.isEmpty else {
                return
            }
            localStatus = .recording
            localConflictMessage = nil
        }
        .onChange(of: triggerMode) { _, newValue in
            guard var existingGesture = gesture else {
                return
            }
            existingGesture.triggerMode = newValue
            gesture = existingGesture
        }
        .onChange(of: isPopoverPresented) { _, isPresented in
            if isPresented {
                beginRecordingSession(resetState: true)
            } else {
                stopRecording(cancelled: true)
            }
        }
        .onAppear {
            if triggerMode == .singleTap {
                triggerMode = .hold
            }
        }
        .onDisappear {
            stopRecording(cancelled: true)
            closeTask?.cancel()
            restartTask?.cancel()
        }
    }

    private var shortcutInputField: some View {
        HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            if displayKeys.isEmpty {
                Text("settings.shortcuts.modifier.input_placeholder".localized)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ShortcutChipRow(keys: displayKeys, colorStyle: .neutral)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing10)
        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing8)
        .frame(minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                .fill(MeetingAssistantDesignSystem.Colors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MeetingAssistantDesignSystem.Layout.smallCornerRadius)
                .strokeBorder(MeetingAssistantDesignSystem.Colors.separator, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var recordingPopover: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
            HStack(alignment: .center, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
                Text("settings.shortcuts.modifier.popover.recording".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("settings.shortcuts.modifier.popover.example".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    isPopoverPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(MeetingAssistantDesignSystem.Colors.secondaryFill)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.cancel".localized)
            }

            ShortcutChipRow(keys: popoverKeys, colorStyle: popoverColorStyle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let localConflictMessage {
                Text(localConflictMessage)
                    .font(.caption)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            } else if localStatus == .success {
                Text("settings.shortcuts.modifier.popover.success".localized)
                    .font(.caption)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.success)
            } else {
                Text("settings.shortcuts.modifier.popover.hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var displayKeys: [ModifierShortcutKey] {
        gesture?.keys ?? []
    }

    private var popoverKeys: [ModifierShortcutKey] {
        if !recorder.currentKeys.isEmpty {
            return recorder.currentKeys
        }
        if let attemptedKeys {
            return attemptedKeys
        }
        return displayKeys
    }

    private var popoverColorStyle: ShortcutChipColorStyle {
        switch localStatus {
        case .success:
            .success
        case .failure:
            .error
        case .idle, .recording:
            .neutral
        }
    }

    private func openRecordingPopover() {
        isPopoverPresented = true
    }

    private func beginRecordingSession(resetState: Bool) {
        closeTask?.cancel()
        restartTask?.cancel()

        if resetState {
            localStatus = .recording
            localConflictMessage = nil
            attemptedKeys = nil
        }

        recorder.start { capturedKeys in
            handleCapturedKeys(capturedKeys)
        }
    }

    private func stopRecording(cancelled: Bool) {
        recorder.stopRecording(cancelled: cancelled)
    }

    private func handleCapturedKeys(_ keys: [ModifierShortcutKey]) {
        attemptedKeys = keys
        localStatus = .recording
        localConflictMessage = nil

        let appliedMode = triggerMode == .singleTap ? .hold : triggerMode
        let candidate = ModifierShortcutGesture(keys: keys, triggerMode: appliedMode)
        gesture = candidate

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard attemptedKeys == keys else {
                return
            }

            if conflictMessage == nil, gesture?.keys == keys {
                localStatus = .success
                closeTask?.cancel()
                closeTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    isPopoverPresented = false
                }
            } else if let conflictMessage {
                localStatus = .failure
                localConflictMessage = conflictMessage
                scheduleRecordingRestart()
            }
        }
    }

    private func scheduleRecordingRestart() {
        restartTask?.cancel()
        restartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, isPopoverPresented else { return }
            beginRecordingSession(resetState: false)
        }
    }
}

private enum ShortcutChipColorStyle {
    case neutral
    case success
    case error
}

private enum ShortcutKeyCode {
    static let leftCommand: UInt16 = 0x37
    static let rightCommand: UInt16 = 0x36
    static let leftOption: UInt16 = 0x3a
    static let rightOption: UInt16 = 0x3d
    static let leftShift: UInt16 = 0x38
    static let rightShift: UInt16 = 0x3c
    static let leftControl: UInt16 = 0x3b
    static let rightControl: UInt16 = 0x3e
    static let fn: UInt16 = 0x3f
    static let escape: UInt16 = 0x35
}

private struct ShortcutChipRow: View {
    let keys: [ModifierShortcutKey]
    let colorStyle: ShortcutChipColorStyle

    var body: some View {
        if keys.isEmpty {
            Text("settings.shortcuts.modifier.none".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                ForEach(keys, id: \.self) { key in
                    Text(key.tokenLabel(in: keys))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, MeetingAssistantDesignSystem.Layout.spacing8)
                        .padding(.vertical, MeetingAssistantDesignSystem.Layout.spacing4)
                        .background(chipBackground)
                        .foregroundStyle(chipForeground)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var chipBackground: Color {
        switch colorStyle {
        case .neutral:
            MeetingAssistantDesignSystem.Colors.secondaryFill
        case .success:
            MeetingAssistantDesignSystem.Colors.success.opacity(0.2)
        case .error:
            MeetingAssistantDesignSystem.Colors.error.opacity(0.2)
        }
    }

    private var chipForeground: Color {
        switch colorStyle {
        case .neutral:
            Color.primary
        case .success:
            MeetingAssistantDesignSystem.Colors.success
        case .error:
            MeetingAssistantDesignSystem.Colors.error
        }
    }
}

private extension ModifierShortcutKey {
    func tokenLabel(in selectedKeys: [ModifierShortcutKey]) -> String {
        switch self {
        case .leftCommand:
            selectedKeys.contains(.rightCommand) ? "L⌘" : "⌘"
        case .rightCommand:
            selectedKeys.contains(.leftCommand) ? "R⌘" : "⌘"
        case .leftShift:
            selectedKeys.contains(.rightShift) ? "L⇧" : "⇧"
        case .rightShift:
            selectedKeys.contains(.leftShift) ? "R⇧" : "⇧"
        case .leftOption:
            selectedKeys.contains(.rightOption) ? "L⌥" : "⌥"
        case .rightOption:
            selectedKeys.contains(.leftOption) ? "R⌥" : "⌥"
        case .leftControl:
            selectedKeys.contains(.rightControl) ? "L⌃" : "⌃"
        case .rightControl:
            selectedKeys.contains(.leftControl) ? "R⌃" : "⌃"
        case .fn:
            "Fn"
        case .command:
            "⌘"
        case .shift:
            "⇧"
        case .option:
            "⌥"
        case .control:
            "⌃"
        }
    }
}

@MainActor
private final class ModifierShortcutRecorderController: ObservableObject {
    @Published private(set) var currentKeys: [ModifierShortcutKey] = []

    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?
    private var pressedKeys = Set<ModifierShortcutKey>()
    private var lastCapturedKeys: [ModifierShortcutKey] = []
    private var completion: (([ModifierShortcutKey]) -> Void)?

    func start(completion: @escaping ([ModifierShortcutKey]) -> Void) {
        stopRecording(cancelled: true)
        self.completion = completion
        pressedKeys.removeAll()
        currentKeys = []
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
        currentKeys = []
        lastCapturedKeys = []

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

        currentKeys = pressedKeys.sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }

        if !currentKeys.isEmpty {
            lastCapturedKeys = currentKeys
        }

        if pressedKeys.isEmpty, !lastCapturedKeys.isEmpty {
            stopRecording(cancelled: false)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == ShortcutKeyCode.escape {
            stopRecording(cancelled: true)
        }
    }

    private static func modifierKey(for keyCode: UInt16) -> ModifierShortcutKey? {
        switch keyCode {
        case ShortcutKeyCode.leftCommand: .leftCommand
        case ShortcutKeyCode.rightCommand: .rightCommand
        case ShortcutKeyCode.leftShift: .leftShift
        case ShortcutKeyCode.rightShift: .rightShift
        case ShortcutKeyCode.leftOption: .leftOption
        case ShortcutKeyCode.rightOption: .rightOption
        case ShortcutKeyCode.leftControl: .leftControl
        case ShortcutKeyCode.rightControl: .rightControl
        case ShortcutKeyCode.fn: .fn
        default: nil
        }
    }
}

#Preview("Empty") {
    PreviewStateContainer(ModifierShortcutGesture?.none) { gesture in
        PreviewStateContainer(ModifierShortcutTriggerMode.hold) { triggerMode in
            MAModifierShortcutEditor(
                gesture: gesture,
                triggerMode: triggerMode,
                conflictMessage: nil
            )
            .padding()
            .frame(width: 560)
        }
    }
}

#Preview("Conflict") {
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
            .frame(width: 560)
        }
    }
}
