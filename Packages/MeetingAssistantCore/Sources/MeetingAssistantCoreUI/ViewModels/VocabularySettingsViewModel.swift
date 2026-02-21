import Combine
import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public final class VocabularySettingsViewModel: ObservableObject {
    public enum ValidationError: Equatable {
        case emptyFind
        case duplicatedFind
    }

    @Published public var showRuleEditor = false
    @Published public var editingRule: VocabularyReplacementRule?
    @Published public var showDeleteConfirmation = false
    @Published public var ruleToDelete: VocabularyReplacementRule?
    @Published public var editorValidationError: ValidationError?

    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var rules: [VocabularyReplacementRule] {
        settings.vocabularyReplacementRules
    }

    public func startCreatingRule() {
        editingRule = nil
        editorValidationError = nil
        showRuleEditor = true
    }

    public func startEditingRule(_ rule: VocabularyReplacementRule) {
        editingRule = rule
        editorValidationError = nil
        showRuleEditor = true
    }

    public func dismissRuleEditor() {
        editorValidationError = nil
        editingRule = nil
        showRuleEditor = false
    }

    @discardableResult
    public func saveRule(find: String, replace: String) -> Bool {
        let normalizedFind = find.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedFind.isEmpty else {
            editorValidationError = .emptyFind
            return false
        }

        let editingRuleId = editingRule?.id
        let normalizedFindKey = normalizedFind.lowercased()
        let hasDuplicate = settings.vocabularyReplacementRules.contains {
            guard $0.id != editingRuleId else { return false }
            return $0.find.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedFindKey
        }
        guard !hasDuplicate else {
            editorValidationError = .duplicatedFind
            return false
        }

        let normalizedReplace = replace.trimmingCharacters(in: .whitespacesAndNewlines)
        var updatedRules = settings.vocabularyReplacementRules
        let updatedRule = VocabularyReplacementRule(
            id: editingRuleId ?? UUID(),
            find: normalizedFind,
            replace: normalizedReplace
        )

        if let editingRuleId,
           let index = updatedRules.firstIndex(where: { $0.id == editingRuleId })
        {
            updatedRules[index] = updatedRule
        } else {
            updatedRules.append(updatedRule)
        }

        settings.vocabularyReplacementRules = updatedRules
        dismissRuleEditor()
        return true
    }

    public func confirmDelete(_ rule: VocabularyReplacementRule) {
        ruleToDelete = rule
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        guard let rule = ruleToDelete else {
            showDeleteConfirmation = false
            return
        }

        settings.vocabularyReplacementRules.removeAll { $0.id == rule.id }
        if editingRule?.id == rule.id {
            dismissRuleEditor()
        }

        ruleToDelete = nil
        showDeleteConfirmation = false
    }
}
