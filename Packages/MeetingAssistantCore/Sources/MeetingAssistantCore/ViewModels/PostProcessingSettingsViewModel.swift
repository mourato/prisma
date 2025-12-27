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
        if self.editingPrompt != nil {
            self.settings.updatePrompt(prompt)
        } else {
            self.settings.addPrompt(prompt)
        }
        self.showPromptEditor = false
    }

    public func confirmDeletePrompt(_ prompt: PostProcessingPrompt) {
        self.promptToDelete = prompt
        self.showDeleteConfirmation = true
    }

    public func executeDelete() {
        if let prompt = self.promptToDelete {
            self.settings.deletePrompt(id: prompt.id)
        }
        self.showDeleteConfirmation = false
        self.promptToDelete = nil
    }

    public func resetSystemPrompt() {
        self.settings.resetSystemPrompt()
    }

    public func selectPrompt(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.settings.selectedPromptId = (self.settings.selectedPromptId == id) ? nil : id
        }
    }
}
