import AppKit
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct MAModifierShortcutEditor: View {
    @Binding private var shortcut: ShortcutDefinition?
    private let conflictMessage: String?
    private let showsTitle: Bool
    private let maxInputWidth: CGFloat?

    @StateObject private var recorder = ShortcutRecorderController()
    @State private var isPopoverPresented = false
    @State private var localStatus: RecordingStatus = .idle
    @State private var localConflictMessage: String?
    @State private var attemptedShortcut: ShortcutDefinition?
    @State private var closeTask: Task<Void, Never>?
    @State private var restartTask: Task<Void, Never>?

    private enum RecordingStatus {
        case idle
        case recording
        case success
        case failure
    }

    public init(
        shortcut: Binding<ShortcutDefinition?>,
        conflictMessage: String?,
        showsTitle: Bool = true,
        maxInputWidth: CGFloat? = 200
    ) {
        _shortcut = shortcut
        self.conflictMessage = conflictMessage
        self.showsTitle = showsTitle
        self.maxInputWidth = maxInputWidth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
            if showsTitle {
                Text("settings.shortcuts.modifier.title".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                Button {
                    openRecordingPopover()
                } label: {
                    shortcutInputField
                }
                .buttonStyle(.plain)
                .frame(maxWidth: maxInputWidth, alignment: .leading)
                .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                    recordingPopover
                        .frame(width: 360)
                        .padding(MeetingAssistantDesignSystem.Layout.spacing12)
                }

                if shortcut != nil {
                    Button {
                        clearShortcut()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .help("settings.shortcuts.modifier.clear".localized)
                    .accessibilityLabel("settings.shortcuts.modifier.clear".localized)
                }
            }

            if let conflict = conflictMessage, !isPopoverPresented {
                Text(conflict)
                    .font(.caption)
                    .foregroundStyle(MeetingAssistantDesignSystem.Colors.error)
            }
        }
        .onChange(of: conflictMessage) { _, newValue in
            guard isPopoverPresented, attemptedShortcut != nil else {
                return
            }

            if let newValue {
                closeTask?.cancel()
                localStatus = .failure
                localConflictMessage = newValue
                scheduleRecordingRestart()
            }
        }
        .onChange(of: recorder.previewLabels) { _, newValue in
            guard !newValue.isEmpty else {
                return
            }
            localStatus = .recording
            localConflictMessage = nil
        }
        .onChange(of: isPopoverPresented) { _, isPresented in
            if isPresented {
                beginRecordingSession(resetState: true)
            } else {
                stopRecording(cancelled: true)
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
            if displayLabels.isEmpty {
                Text("settings.shortcuts.modifier.input_placeholder".localized)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ShortcutChipRow(labels: displayLabels, colorStyle: .neutral)
            }

            Spacer(minLength: 0)
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
                        .padding(MeetingAssistantDesignSystem.Layout.compactInset)
                        .background(
                            Circle()
                                .fill(MeetingAssistantDesignSystem.Colors.secondaryFill)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.cancel".localized)
            }

            ShortcutChipRow(labels: popoverLabels, colorStyle: popoverColorStyle)
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

    private var displayLabels: [String] {
        labels(for: shortcut)
    }

    private var popoverLabels: [String] {
        if !recorder.previewLabels.isEmpty {
            return recorder.previewLabels
        }
        if let attemptedShortcut {
            return labels(for: attemptedShortcut)
        }
        return displayLabels
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

    private func clearShortcut() {
        closeTask?.cancel()
        restartTask?.cancel()
        attemptedShortcut = nil
        localStatus = .idle
        localConflictMessage = nil
        stopRecording(cancelled: true)
        shortcut = nil
        isPopoverPresented = false
    }

    private func beginRecordingSession(resetState: Bool) {
        closeTask?.cancel()
        restartTask?.cancel()

        if resetState {
            localStatus = .recording
            localConflictMessage = nil
            attemptedShortcut = nil
        }

        recorder.start { capturedShortcut in
            handleCapturedShortcut(capturedShortcut)
        }
    }

    private func stopRecording(cancelled: Bool) {
        recorder.stopRecording(cancelled: cancelled)
    }

    private func handleCapturedShortcut(_ capturedShortcut: ShortcutDefinition) {
        attemptedShortcut = capturedShortcut
        localStatus = .recording
        localConflictMessage = nil

        shortcut = capturedShortcut

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard attemptedShortcut == capturedShortcut else {
                return
            }

            if conflictMessage == nil, shortcut == capturedShortcut {
                localStatus = .success
                closeTask?.cancel()
                closeTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    isPopoverPresented = false
                }
            } else if let conflictMessage {
                closeTask?.cancel()
                localStatus = .failure
                localConflictMessage = conflictMessage
                scheduleRecordingRestart()
            }
        }
    }

    private func scheduleRecordingRestart() {
        closeTask?.cancel()
        restartTask?.cancel()
        restartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, isPopoverPresented else { return }
            beginRecordingSession(resetState: false)
        }
    }

    private func labels(for shortcut: ShortcutDefinition?) -> [String] {
        guard let shortcut else {
            return []
        }

        var labels = shortcut.modifiers.map { $0.tokenLabel(in: shortcut.modifiers) }

        if let primaryKey = shortcut.primaryKey {
            labels.append(primaryKey.display)
            return labels
        }

        if shortcut.trigger == .doubleTap, labels.count == 1 {
            labels.append(labels[0])
        }

        return labels
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
    static let space: UInt16 = 0x31

    static let functionKeyByCode: [UInt16: Int] = [
        0x7a: 1,
        0x78: 2,
        0x63: 3,
        0x76: 4,
        0x60: 5,
        0x61: 6,
        0x62: 7,
        0x64: 8,
        0x65: 9,
        0x6d: 10,
        0x67: 11,
        0x6f: 12,
        0x69: 13,
        0x6b: 14,
        0x71: 15,
        0x6a: 16,
        0x40: 17,
        0x4f: 18,
        0x50: 19,
        0x5a: 20,
    ]
}

private struct ShortcutChipRow: View {
    let labels: [String]
    let colorStyle: ShortcutChipColorStyle

    var body: some View {
        if labels.isEmpty {
            Text("settings.shortcuts.modifier.none".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                    Text(label)
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
private final class ShortcutRecorderController: ObservableObject {
    @Published private(set) var previewLabels: [String] = []

    private var flagsMonitor: KeyboardEventMonitor?
    private var keyDownMonitor: KeyboardEventMonitor?
    private var pressedModifiers = Set<ModifierShortcutKey>()
    private var completion: ((ShortcutDefinition) -> Void)?
    private var lastModifierTap: (key: ModifierShortcutKey, date: Date)?
    private let doubleTapInterval: TimeInterval = 0.25

    func start(completion: @escaping (ShortcutDefinition) -> Void) {
        stopRecording(cancelled: true)
        self.completion = completion
        pressedModifiers.removeAll()
        previewLabels = []
        lastModifierTap = nil

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

        if cancelled {
            completion = nil
        }

        pressedModifiers.removeAll()
        lastModifierTap = nil
        previewLabels = []
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard let key = Self.modifierKey(for: event.keyCode) else {
            return
        }

        let wasPressed = pressedModifiers.contains(key)
        if wasPressed {
            pressedModifiers.remove(key)
        } else {
            pressedModifiers.insert(key)
            handleModifierPress(key)
        }

        updatePreviewFromCurrentState()
    }

    private func handleModifierPress(_ key: ModifierShortcutKey) {
        guard pressedModifiers.count == 1 else {
            lastModifierTap = nil
            return
        }

        let now = Date()
        if let lastModifierTap,
           lastModifierTap.key == key,
           now.timeIntervalSince(lastModifierTap.date) <= doubleTapInterval
        {
            commit(
                ShortcutDefinition(
                    modifiers: [key],
                    primaryKey: nil,
                    trigger: .doubleTap
                )
            )
            return
        }

        lastModifierTap = (key, now)
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !event.isARepeat else {
            return
        }

        if event.keyCode == ShortcutKeyCode.escape {
            stopRecording(cancelled: true)
            return
        }

        if Self.modifierKey(for: event.keyCode) != nil {
            return
        }

        guard !pressedModifiers.isEmpty else {
            return
        }

        guard let primaryKey = Self.primaryKey(for: event) else {
            return
        }

        let simpleModifiers = canonicalSimpleOrIntermediateModifiers(Array(pressedModifiers))
        let definition = ShortcutDefinition(
            modifiers: simpleModifiers,
            primaryKey: primaryKey,
            trigger: .singleTap
        )
        commit(definition)
    }

    private func commit(_ definition: ShortcutDefinition) {
        guard definition.isValid else {
            return
        }

        let completionHandler = completion
        completion = nil
        stopRecording(cancelled: true)
        previewLabels = displayLabels(for: definition)
        completionHandler?(definition)
    }

    private func updatePreviewFromCurrentState() {
        let sorted = pressedModifiers.sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }
        previewLabels = sorted.map { $0.tokenLabel(in: sorted) }
    }

    private func displayLabels(for definition: ShortcutDefinition) -> [String] {
        var labels = definition.modifiers.map { $0.tokenLabel(in: definition.modifiers) }
        if let primaryKey = definition.primaryKey {
            labels.append(primaryKey.display)
        } else if definition.trigger == .doubleTap, labels.count == 1 {
            labels.append(labels[0])
        }
        return labels
    }

    private func canonicalSimpleOrIntermediateModifiers(_ modifiers: [ModifierShortcutKey]) -> [ModifierShortcutKey] {
        let mapped = modifiers.map { key -> ModifierShortcutKey in
            switch key {
            case .leftCommand, .rightCommand, .command:
                .command
            case .leftShift, .rightShift, .shift:
                .shift
            case .leftOption, .rightOption, .option:
                .option
            case .leftControl, .rightControl, .control:
                .control
            case .fn:
                .fn
            }
        }

        return Array(Set(mapped))
            .sorted { lhs, rhs in
                lhs.sortOrder < rhs.sortOrder
            }
    }

    private static func primaryKey(for event: NSEvent) -> ShortcutPrimaryKey? {
        if let functionIndex = ShortcutKeyCode.functionKeyByCode[event.keyCode] {
            return .function(index: functionIndex, keyCode: event.keyCode)
        }

        if event.keyCode == ShortcutKeyCode.space {
            return .space(keyCode: event.keyCode)
        }

        guard let characters = event.charactersIgnoringModifiers,
              let scalar = characters.unicodeScalars.first
        else {
            return nil
        }

        let display = String(scalar)
        if scalar.properties.isAlphabetic {
            return .letter(display, keyCode: event.keyCode)
        }

        if scalar.properties.numericType != nil {
            return .digit(display, keyCode: event.keyCode)
        }

        return .symbol(display, keyCode: event.keyCode)
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
    PreviewStateContainer(ShortcutDefinition?.none) { shortcut in
        MAModifierShortcutEditor(
            shortcut: shortcut,
            conflictMessage: nil
        )
        .padding()
        .frame(width: 560)
    }
}

#Preview("Conflict") {
    PreviewStateContainer(
        Optional(
            ShortcutDefinition(
                modifiers: [.rightCommand],
                primaryKey: nil,
                trigger: .doubleTap
            )
        )
    ) { shortcut in
        MAModifierShortcutEditor(
            shortcut: shortcut,
            conflictMessage: "settings.shortcuts.modifier.conflict".localized(with: "Meeting Shortcut")
        )
        .padding()
        .frame(width: 560)
    }
}
