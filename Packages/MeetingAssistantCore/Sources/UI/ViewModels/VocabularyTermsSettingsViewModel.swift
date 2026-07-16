import Combine
import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
public final class VocabularyTermsSettingsViewModel: ObservableObject {
    public enum ValidationError: Equatable {
        case emptyTerm
        case duplicatedTerm(String)
    }

    @Published public var terms: [VocabularyTerm] = []
    @Published public var bulkInputText = ""
    @Published public var validationError: ValidationError?
    @Published public var showDeleteConfirmation = false
    @Published public var termToDelete: VocabularyTerm?
    @Published public var addedTermsCount = 0

    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings
        terms = settings.vocabularyTerms

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func reloadFromStore() {
        terms = settings.vocabularyTerms
    }

    /// Adds comma-separated terms from `bulkInputText`. Returns the count of terms added.
    @discardableResult
    public func addTermsFromBulkInput() -> Int {
        let rawInput = bulkInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty else {
            validationError = .emptyTerm
            return 0
        }

        let rawTerms = rawInput
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !rawTerms.isEmpty else {
            validationError = .emptyTerm
            return 0
        }

        var addedCount = 0
        var updatedTerms = settings.vocabularyTerms

        for rawTerm in rawTerms {
            // Check for duplicates against existing terms (case-insensitive)
            let lowerRaw = rawTerm.lowercased()
            let isDuplicate = updatedTerms.contains { $0.term.lowercased() == lowerRaw }
            guard !isDuplicate else {
                validationError = .duplicatedTerm(rawTerm)
                continue
            }

            updatedTerms.append(VocabularyTerm(term: rawTerm, definition: ""))
            addedCount += 1
        }

        guard addedCount > 0 else {
            return 0
        }

        settings.vocabularyTerms = updatedTerms
        terms = updatedTerms
        bulkInputText = ""
        validationError = nil
        addedTermsCount = addedCount
        return addedCount
    }

    public func confirmDelete(_ term: VocabularyTerm) {
        termToDelete = term
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        guard let term = termToDelete else {
            showDeleteConfirmation = false
            return
        }

        var updatedTerms = settings.vocabularyTerms
        updatedTerms.removeAll { $0.id == term.id }
        settings.vocabularyTerms = updatedTerms
        terms = updatedTerms

        termToDelete = nil
        showDeleteConfirmation = false
    }

    public func removeTerm(_ term: VocabularyTerm) {
        var updatedTerms = settings.vocabularyTerms
        updatedTerms.removeAll { $0.id == term.id }
        settings.vocabularyTerms = updatedTerms
        terms = updatedTerms
    }
}
