import Foundation
import SwiftUI

@MainActor
public class PostProcessingSettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showPromptEditor = false
    @Published public var editingPrompt: PostProcessingPrompt?
    @Published public var showDeleteConfirmation = false
    @Published public var promptToDelete: PostProcessingPrompt?

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

    public func selectPrompt(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.settings.selectedPromptId = (self.settings.selectedPromptId == id) ? nil : id
        }
    }
}
