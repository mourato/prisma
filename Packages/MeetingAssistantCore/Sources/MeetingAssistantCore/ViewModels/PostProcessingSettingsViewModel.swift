import Foundation
import SwiftUI

@MainActor
public class PostProcessingSettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showPromptEditor = false
    @Published public var editingPrompt: PostProcessingPrompt?
    @Published public var showDeleteConfirmation = false
    @Published public var promptToDelete: PostProcessingPrompt?
    @Published public var showSystemPromptEditor = false

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings
    }

    public func handleSavePrompt(_ prompt: PostProcessingPrompt) {
        if editingPrompt != nil {
            settings.updatePrompt(prompt)
        } else {
            settings.addPrompt(prompt)
        }
        showPromptEditor = false
    }

    public func confirmDeletePrompt(_ prompt: PostProcessingPrompt) {
        promptToDelete = prompt
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        if let prompt = promptToDelete {
            settings.deletePrompt(id: prompt.id)
        }
        showDeleteConfirmation = false
        promptToDelete = nil
    }

    public func resetSystemPrompt() {
        settings.resetSystemPrompt()
    }

    public func duplicatePrompt(_ prompt: PostProcessingPrompt) {
        var copy = prompt
        copy.title = "\(prompt.title) (\("settings.post_processing.duplicate".localized))"
        // Force a new ID and make it non-predefined
        let newPrompt = PostProcessingPrompt(
            title: copy.title,
            promptText: prompt.promptText,
            isActive: false,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: false
        )
        editingPrompt = newPrompt
        showPromptEditor = true
    }

    public func handleSaveSystemPrompt(_ newPrompt: String) {
        settings.systemPrompt = newPrompt
        showSystemPromptEditor = false
    }

    public func selectPrompt(_ id: UUID, forceSelect: Bool = false) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if forceSelect {
                self.settings.selectedPromptId = id
            } else {
                self.settings.selectedPromptId = (self.settings.selectedPromptId == id) ? nil : id
            }
        }
    }
}
