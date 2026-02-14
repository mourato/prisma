import Combine
import Foundation
import KeyboardShortcuts
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Shortcut Settings View Model

@MainActor
public class ShortcutSettingsViewModel: ObservableObject {
    private let settings = AppSettingsStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published public var activationMode: ShortcutActivationMode
    @Published public var dictationActivationMode: ShortcutActivationMode
    @Published public var useEscapeToCancelRecording: Bool
    @Published public var selectedPresetKey: PresetShortcutKey
    @Published public var dictationSelectedPresetKey: PresetShortcutKey
    @Published public var meetingSelectedPresetKey: PresetShortcutKey
    @Published public var dictationModifierShortcutGesture: ModifierShortcutGesture?
    @Published public var dictationModifierTriggerMode: ModifierShortcutTriggerMode
    @Published public var dictationModifierConflictMessage: String?
    @Published public var meetingModifierShortcutGesture: ModifierShortcutGesture?
    @Published public var meetingModifierTriggerMode: ModifierShortcutTriggerMode
    @Published public var meetingModifierConflictMessage: String?
    @Published public var testKeysInput: String = ""

    /// Whether the user is recording a custom shortcut
    @Published public var isRecordingCustomShortcut: Bool = false
    private var isApplyingModifierShortcutChange = false

    // MARK: - Initialization

    public init() {
        activationMode = settings.shortcutActivationMode
        dictationActivationMode = settings.dictationShortcutActivationMode
        useEscapeToCancelRecording = settings.useEscapeToCancelRecording
        selectedPresetKey = settings.selectedPresetKey
        dictationSelectedPresetKey = settings.dictationSelectedPresetKey
        meetingSelectedPresetKey = settings.meetingSelectedPresetKey
        dictationModifierShortcutGesture = settings.dictationModifierShortcutGesture
        dictationModifierTriggerMode = settings.dictationModifierShortcutGesture?.triggerMode ?? .singleTap
        dictationModifierConflictMessage = nil
        meetingModifierShortcutGesture = settings.meetingModifierShortcutGesture
        meetingModifierTriggerMode = settings.meetingModifierShortcutGesture?.triggerMode ?? .singleTap
        meetingModifierConflictMessage = nil

        setupBindings()
    }

    // MARK: - Private Setup

    private func setupBindings() {
        // Sync activation mode changes to settings
        $activationMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.shortcutActivationMode = newValue
            }
            .store(in: &cancellables)

        // Sync Dictation activation mode changes to settings
        $dictationActivationMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.dictationShortcutActivationMode = newValue
            }
            .store(in: &cancellables)

        // Sync escape cancel setting
        $useEscapeToCancelRecording
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.useEscapeToCancelRecording = newValue
            }
            .store(in: &cancellables)

        // Sync preset key selection
        $selectedPresetKey
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.selectedPresetKey = newValue
                // When user selects custom, show the recorder
                self?.isRecordingCustomShortcut = (newValue == .custom)
            }
            .store(in: &cancellables)

        // Sync Dictation preset
        $dictationSelectedPresetKey
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.dictationSelectedPresetKey = newValue
            }
            .store(in: &cancellables)

        // Sync Meeting preset
        $meetingSelectedPresetKey
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.meetingSelectedPresetKey = newValue
            }
            .store(in: &cancellables)

        $dictationModifierShortcutGesture
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleDictationModifierGestureChange(newValue)
            }
            .store(in: &cancellables)

        $dictationModifierTriggerMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleDictationModifierTriggerModeChange(newValue)
            }
            .store(in: &cancellables)

        $meetingModifierShortcutGesture
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleMeetingModifierGestureChange(newValue)
            }
            .store(in: &cancellables)

        $meetingModifierTriggerMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleMeetingModifierTriggerModeChange(newValue)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Resets all keyboard shortcuts to their default values.
    public func resetShortcuts() {
        KeyboardShortcuts.reset(.toggleRecording)
        KeyboardShortcuts.reset(.dictationToggle)
        KeyboardShortcuts.reset(.meetingToggle)
        activationMode = .holdOrToggle
        dictationActivationMode = .holdOrToggle
        useEscapeToCancelRecording = false
        selectedPresetKey = .fn
        dictationSelectedPresetKey = .fn
        meetingSelectedPresetKey = .notSpecified
        dictationModifierShortcutGesture = nil
        dictationModifierTriggerMode = .singleTap
        dictationModifierConflictMessage = nil
        meetingModifierShortcutGesture = nil
        meetingModifierTriggerMode = .singleTap
        meetingModifierConflictMessage = nil
        isRecordingCustomShortcut = false
    }

    private func handleDictationModifierGestureChange(_ newValue: ModifierShortcutGesture?) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        let normalizedValue = newValue.map {
            ModifierShortcutGesture(keys: $0.keys, triggerMode: dictationModifierTriggerMode)
        }

        guard let normalizedValue else {
            settings.dictationModifierShortcutGesture = nil
            settings.dictationShortcutDefinition = nil
            dictationModifierConflictMessage = nil
            return
        }

        let candidate = ShortcutBinding(
            actionID: .dictation,
            actionDisplayName: "settings.shortcuts.dictation".localized,
            shortcut: normalizedValue.asShortcutDefinition
        )

        if let conflict = settings.shortcutConflict(for: candidate) {
            isApplyingModifierShortcutChange = true
            dictationModifierShortcutGesture = settings.dictationModifierShortcutGesture
            dictationModifierTriggerMode = settings.dictationModifierShortcutGesture?.triggerMode ?? .singleTap
            dictationModifierConflictMessage = "settings.shortcuts.modifier.conflict".localized(with: conflict.conflicting.actionDisplayName)
            isApplyingModifierShortcutChange = false
            return
        }

        settings.dictationModifierShortcutGesture = normalizedValue
        settings.dictationShortcutDefinition = normalizedValue.asShortcutDefinition
        dictationModifierConflictMessage = nil
    }

    private func handleDictationModifierTriggerModeChange(_ newValue: ModifierShortcutTriggerMode) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        guard let gesture = dictationModifierShortcutGesture else {
            return
        }

        let updatedGesture = ModifierShortcutGesture(keys: gesture.keys, triggerMode: newValue)
        if updatedGesture == dictationModifierShortcutGesture {
            return
        }

        isApplyingModifierShortcutChange = true
        dictationModifierShortcutGesture = updatedGesture
        isApplyingModifierShortcutChange = false
        handleDictationModifierGestureChange(updatedGesture)
    }

    private func handleMeetingModifierGestureChange(_ newValue: ModifierShortcutGesture?) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        let normalizedValue = newValue.map {
            ModifierShortcutGesture(keys: $0.keys, triggerMode: meetingModifierTriggerMode)
        }

        guard let normalizedValue else {
            settings.meetingModifierShortcutGesture = nil
            settings.meetingShortcutDefinition = nil
            meetingModifierConflictMessage = nil
            return
        }

        let candidate = ShortcutBinding(
            actionID: .meeting,
            actionDisplayName: "settings.shortcuts.meeting".localized,
            shortcut: normalizedValue.asShortcutDefinition
        )

        if let conflict = settings.shortcutConflict(for: candidate) {
            isApplyingModifierShortcutChange = true
            meetingModifierShortcutGesture = settings.meetingModifierShortcutGesture
            meetingModifierTriggerMode = settings.meetingModifierShortcutGesture?.triggerMode ?? .singleTap
            meetingModifierConflictMessage = "settings.shortcuts.modifier.conflict".localized(with: conflict.conflicting.actionDisplayName)
            isApplyingModifierShortcutChange = false
            return
        }

        settings.meetingModifierShortcutGesture = normalizedValue
        settings.meetingShortcutDefinition = normalizedValue.asShortcutDefinition
        meetingModifierConflictMessage = nil
    }

    private func handleMeetingModifierTriggerModeChange(_ newValue: ModifierShortcutTriggerMode) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        guard let gesture = meetingModifierShortcutGesture else {
            return
        }

        let updatedGesture = ModifierShortcutGesture(keys: gesture.keys, triggerMode: newValue)
        if updatedGesture == meetingModifierShortcutGesture {
            return
        }

        isApplyingModifierShortcutChange = true
        meetingModifierShortcutGesture = updatedGesture
        isApplyingModifierShortcutChange = false
        handleMeetingModifierGestureChange(updatedGesture)
    }
}
