import Foundation

/// Deterministic find-and-replace rule applied to transcription text.
public struct VocabularyReplacementRule: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var find: String
    public var replace: String

    public init(id: UUID = UUID(), find: String, replace: String) {
        self.id = id
        self.find = find
        self.replace = replace
    }
}
