import Foundation

/// A vocabulary term with its definition, used for recognition/spelling hints
/// during transcription. Comma-separated bulk input is supported during entry;
/// each term is stored as a single unit.
public struct VocabularyTerm: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var term: String
    public var definition: String

    public init(id: UUID = UUID(), term: String, definition: String) {
        self.id = id
        self.term = term
        self.definition = definition
    }
}

extension VocabularyTerm: Comparable {
    public static func < (lhs: VocabularyTerm, rhs: VocabularyTerm) -> Bool {
        lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
    }
}
