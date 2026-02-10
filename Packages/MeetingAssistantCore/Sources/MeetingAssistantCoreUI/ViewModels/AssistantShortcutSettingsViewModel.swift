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

@MainActor
public final class AssistantShortcutSettingsViewModel: ObservableObject {
    private let settings = AppSettingsStore.shared
    private var cancellables = Set<AnyCancellable>()

    @Published public var activationMode: ShortcutActivationMode
    @Published public var useEscapeToCancelRecording: Bool
    @Published public var selectedPresetKey: PresetShortcutKey
    @Published public var testKeysInput: String = ""
    @Published public var isRecordingCustomShortcut: Bool = false
    @Published public var borderColor: AssistantBorderColor
    @Published public var borderStyle: AssistantBorderStyle

    public init() {
        activationMode = settings.assistantShortcutActivationMode
        useEscapeToCancelRecording = settings.assistantUseEscapeToCancelRecording
        selectedPresetKey = settings.assistantSelectedPresetKey
        isRecordingCustomShortcut = settings.assistantSelectedPresetKey == .custom
        borderColor = settings.assistantBorderColor
        borderStyle = settings.assistantBorderStyle

        setupBindings()
    }

    private func setupBindings() {
        $activationMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantShortcutActivationMode = newValue
            }
            .store(in: &cancellables)

        $useEscapeToCancelRecording
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantUseEscapeToCancelRecording = newValue
            }
            .store(in: &cancellables)

        $selectedPresetKey
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantSelectedPresetKey = newValue
                self?.isRecordingCustomShortcut = (newValue == .custom)
            }
            .store(in: &cancellables)

        $borderColor
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantBorderColor = newValue
            }
            .store(in: &cancellables)

        $borderStyle
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantBorderStyle = newValue
            }
            .store(in: &cancellables)
    }

    public func resetShortcuts() {
        KeyboardShortcuts.reset(.assistantCommand)
        activationMode = .holdOrToggle
        useEscapeToCancelRecording = false
        selectedPresetKey = .rightOption
        isRecordingCustomShortcut = false
        borderColor = .green
        borderStyle = .stroke
    }
}
