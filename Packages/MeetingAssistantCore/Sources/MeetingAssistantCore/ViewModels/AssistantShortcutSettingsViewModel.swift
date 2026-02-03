import Combine
import Foundation
import KeyboardShortcuts
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

    public init() {
        activationMode = settings.assistantShortcutActivationMode
        useEscapeToCancelRecording = settings.assistantUseEscapeToCancelRecording
        selectedPresetKey = settings.assistantSelectedPresetKey
        isRecordingCustomShortcut = settings.assistantSelectedPresetKey == .custom

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
    }

    public func resetShortcuts() {
        KeyboardShortcuts.reset(.assistantCommand)
        activationMode = .holdOrToggle
        useEscapeToCancelRecording = false
        selectedPresetKey = .rightOption
        isRecordingCustomShortcut = false
    }
}
