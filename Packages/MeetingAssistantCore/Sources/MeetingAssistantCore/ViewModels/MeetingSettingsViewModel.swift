import Combine
import Foundation
import SwiftUI

@MainActor
public class MeetingSettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showPromptEditor = false
    @Published public var editingPrompt: PostProcessingPrompt?
    @Published public var showDeleteConfirmation = false
    @Published public var promptToDelete: PostProcessingPrompt?

    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        // Forward settings changes
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Prompt Management

    public func handleSavePrompt(_ prompt: PostProcessingPrompt) {
        if let index = settings.meetingPrompts.firstIndex(where: { $0.id == prompt.id }) {
            var prompts = settings.meetingPrompts
            prompts[index] = prompt
            settings.meetingPrompts = prompts
        } else {
            var prompts = settings.meetingPrompts
            prompts.append(prompt)
            settings.meetingPrompts = prompts
        }
        showPromptEditor = false
        editingPrompt = nil
    }

    public func confirmDeletePrompt(_ prompt: PostProcessingPrompt) {
        promptToDelete = prompt
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        if let prompt = promptToDelete {
            settings.meetingPrompts.removeAll { $0.id == prompt.id }
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
            id: asDuplicate ? UUID() : prompt.id,
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
    
    // MARK: - Export Configuration
    
    public func selectExportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        
        if panel.runModal() == .OK {
            settings.summaryExportFolder = panel.url
        }
    }
}
