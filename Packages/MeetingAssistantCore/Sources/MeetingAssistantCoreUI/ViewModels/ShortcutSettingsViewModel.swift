import Combine
import Foundation
import KeyboardShortcuts
import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

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
    @Published public var testKeysInput: String = ""

    /// Whether the user is recording a custom shortcut
    @Published public var isRecordingCustomShortcut: Bool = false

    // MARK: - Initialization

    public init() {
        activationMode = settings.shortcutActivationMode
        dictationActivationMode = settings.dictationShortcutActivationMode
        useEscapeToCancelRecording = settings.useEscapeToCancelRecording
        selectedPresetKey = settings.selectedPresetKey
        dictationSelectedPresetKey = settings.dictationSelectedPresetKey
        meetingSelectedPresetKey = settings.meetingSelectedPresetKey

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
        isRecordingCustomShortcut = false
    }
}
