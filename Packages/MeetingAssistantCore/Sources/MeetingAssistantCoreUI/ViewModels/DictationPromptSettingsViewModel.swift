import Combine
import Foundation
import SwiftUI
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public final class DictationPromptSettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showPromptEditor = false
    @Published public var editingPrompt: PostProcessingPrompt?
    @Published public var showDeleteConfirmation = false
    @Published public var promptToDelete: PostProcessingPrompt?

    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var availablePrompts: [PostProcessingPrompt] {
        settings.dictationAvailablePrompts
    }

    public var selectedPromptId: UUID? {
        settings.dictationSelectedPromptId
    }

    public var effectiveSelectedPromptId: UUID {
        if settings.isDictationPostProcessingDisabled {
            return AppSettingsStore.noPostProcessingPromptId
        }

        return settings.dictationSelectedPromptId ?? PostProcessingPrompt.cleanTranscription.id
    }

    public func selectPrompt(_ id: UUID, forceSelect: Bool = false) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if forceSelect {
                settings.dictationSelectedPromptId = id
            } else {
                settings.dictationSelectedPromptId = (settings.dictationSelectedPromptId == id) ? nil : id
            }
        }
    }

    public func handleSavePrompt(_ prompt: PostProcessingPrompt) {
        if let index = settings.dictationPrompts.firstIndex(where: { $0.id == prompt.id }) {
            var prompts = settings.dictationPrompts
            prompts[index] = prompt
            settings.dictationPrompts = prompts
        } else {
            var prompts = settings.dictationPrompts
            prompts.append(prompt)
            settings.dictationPrompts = prompts
        }

        showPromptEditor = false
        editingPrompt = nil
    }

    public func confirmDeletePrompt(_ prompt: PostProcessingPrompt) {
        guard !prompt.isPredefined else { return }
        promptToDelete = prompt
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        if let prompt = promptToDelete {
            settings.dictationPrompts.removeAll { $0.id == prompt.id }
            if settings.dictationSelectedPromptId == prompt.id {
                settings.dictationSelectedPromptId = nil
            }
        }
        showDeleteConfirmation = false
        promptToDelete = nil
    }

    public func prepareCopy(of prompt: PostProcessingPrompt, asDuplicate: Bool) {
        var newTitle = prompt.title
        if asDuplicate {
            newTitle = "\(prompt.title) (\("settings.post_processing.duplicate".localized))"
        }

        let newPrompt = PostProcessingPrompt(
            id: UUID(),
            title: newTitle,
            promptText: prompt.promptText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: false
        )

        editingPrompt = newPrompt
        showPromptEditor = true
    }
}
