import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

@MainActor
public final class AssistantShortcutSettingsViewModel: ObservableObject {
    public static let borderWidthOptions: [Double] = [3, 8, 15, 20, 25, 30]

    private let settings = AppSettingsStore.shared
    private var cancellables = Set<AnyCancellable>()

    @Published public var useEscapeToCancelRecording: Bool
    @Published public var selectedPresetKey: PresetShortcutKey
    @Published public var assistantShortcutDefinition: ShortcutDefinition?
    @Published public var assistantModifierConflictMessage: String?
    @Published public var isRecordingCustomShortcut: Bool = false
    @Published public var borderColor: AssistantBorderColor
    @Published public var borderStyle: AssistantBorderStyle
    @Published public var borderWidth: Double
    @Published public var glowSize: Double
    private var isApplyingModifierShortcutChange = false

    public init() {
        useEscapeToCancelRecording = settings.assistantUseEscapeToCancelRecording
        selectedPresetKey = settings.assistantSelectedPresetKey
        assistantShortcutDefinition = settings.assistantShortcutDefinition
        assistantModifierConflictMessage = nil
        isRecordingCustomShortcut = settings.assistantSelectedPresetKey == .custom
        borderColor = settings.assistantBorderColor
        borderStyle = settings.assistantBorderStyle
        let normalizedBorderWidth = Self.normalizedBorderWidthValue(settings.assistantBorderWidth)
        borderWidth = normalizedBorderWidth
        glowSize = settings.assistantGlowSize

        if normalizedBorderWidth != settings.assistantBorderWidth {
            settings.assistantBorderWidth = normalizedBorderWidth
        }

        setupBindings()
    }

    private func setupBindings() {
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

        $assistantShortcutDefinition
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleAssistantShortcutDefinitionChange(newValue)
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

        $borderWidth
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                let normalized = Self.normalizedBorderWidthValue(newValue)
                settings.assistantBorderWidth = normalized
                if normalized != newValue {
                    borderWidth = normalized
                }
            }
            .store(in: &cancellables)

        $glowSize
            .dropFirst()
            .sink { [weak self] newValue in
                self?.settings.assistantGlowSize = max(0, newValue)
            }
            .store(in: &cancellables)
    }

    private static func normalizedBorderWidthValue(_ value: Double) -> Double {
        borderWidthOptions.min(by: { abs($0 - value) < abs($1 - value) }) ?? borderWidthOptions[1]
    }

    private func handleAssistantShortcutDefinitionChange(_ newValue: ShortcutDefinition?) {
        guard !isApplyingModifierShortcutChange else {
            return
        }

        guard let normalizedValue = normalizedShortcutDefinition(newValue) else {
            settings.assistantModifierShortcutGesture = nil
            settings.assistantShortcutDefinition = nil
            settings.assistantSelectedPresetKey = .notSpecified
            selectedPresetKey = .notSpecified
            assistantModifierConflictMessage = nil
            return
        }

        let candidate = ShortcutBinding(
            actionID: .assistant,
            actionDisplayName: "settings.assistant.toggle_command".localized,
            shortcut: normalizedValue
        )

        if let conflict = settings.shortcutConflict(for: candidate) {
            isApplyingModifierShortcutChange = true
            assistantShortcutDefinition = settings.assistantShortcutDefinition
            assistantModifierConflictMessage = "settings.shortcuts.modifier.conflict".localized(with: conflict.conflicting.actionDisplayName)
            isApplyingModifierShortcutChange = false
            return
        }

        settings.assistantShortcutDefinition = normalizedValue
        settings.assistantModifierShortcutGesture = normalizedValue.asModifierShortcutGesture
        settings.assistantSelectedPresetKey = .custom
        selectedPresetKey = .custom
        assistantModifierConflictMessage = nil
    }

    private func normalizedShortcutDefinition(_ definition: ShortcutDefinition?) -> ShortcutDefinition? {
        guard var definition else {
            return nil
        }

        if definition.primaryKey == nil {
            guard let modifier = definition.modifiers.first else {
                return nil
            }
            definition = ShortcutDefinition(
                modifiers: [modifier],
                primaryKey: nil,
                trigger: .doubleTap
            )
        } else {
            definition = ShortcutDefinition(
                modifiers: definition.modifiers,
                primaryKey: definition.primaryKey,
                trigger: .singleTap
            )
        }

        return definition.isValid ? definition : nil
    }
}
