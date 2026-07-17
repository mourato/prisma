import Foundation

/// An immutable snapshot of vocabulary state captured at session start.
///
/// Captures both vocabulary terms (for provider-side hints) and replacement rules
/// (for deterministic post-hoc substitution). Using a snapshot ensures that
/// mid-recording dictionary changes do not affect the current session.
///
/// ## Provider capability matrix (2026-07-16)
///
/// | Provider | Vocabulary hint via | Supported? | Parameter | Notes |
/// |---|---|---|---|---|
/// | Groq (Whisper) | `prompt` field | ✅ Supported | `prompt` | Whisper API `prompt` provides context/hints; 224 token limit recommended |
/// | ElevenLabs (Scribe) | `custom_prompt` field | ✅ Supported | `custom_prompt` | Scribe v1 accepts optional prompt context |
/// | Local (FluidAudio) | ASR parameter | ❌ Unsupported | N/A | FluidAudio `AsrManager.transcribe()` has no vocabulary/hint parameter |
public struct VocabularySnapshot: Sendable, Equatable {
    /// Vocabulary terms for provider-side recognition hints.
    public let terms: [VocabularyTerm]

    /// Replacement rules for deterministic post-hoc text substitution.
    public let replacementRules: [VocabularyReplacementRule]

    public init(terms: [VocabularyTerm], replacementRules: [VocabularyReplacementRule]) {
        self.terms = terms
        self.replacementRules = replacementRules
    }

    /// A comma-separated hint string for provider API `prompt`/`custom_prompt` parameters.
    /// Returns `nil` when there are no terms.
    public var providerHint: String? {
        let termStrings = terms.map(\.term).filter { !$0.isEmpty }
        guard !termStrings.isEmpty else { return nil }
        return termStrings.joined(separator: ", ")
    }

    /// An empty snapshot — no terms and no replacement rules.
    public static let empty = VocabularySnapshot(terms: [], replacementRules: [])

    /// Prepends this snapshot's vocabulary context block to the base
    /// post-processing context, separated by a blank line. Returns the
    /// base context unchanged when there are no vocabulary terms.
    /// - Parameter baseContext: The existing post-processing context.
    /// - Returns: Combined context or `nil` when neither is present.
    public func prependToContext(_ baseContext: String?) -> String? {
        guard let vocab = postProcessingContext else { return baseContext }
        guard let existing = baseContext,
              !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return vocab
        }
        return vocab + "\n\n" + existing
    }

    /// Composes a delimited vocabulary context block for enhancement models.
    /// Instructs the model to prefer these specific spellings without
    /// inventing content. Returns `nil` when there are no terms.
    public var postProcessingContext: String? {
        let termStrings = terms.map(\.term).filter { !$0.isEmpty }
        guard !termStrings.isEmpty else { return nil }

        let escapedList = termStrings
            .map { $0.replacingOccurrences(of: "\"", with: "\\\"") }
            .map { "\"\($0)\"" }
            .joined(separator: ", ")

        return """
        <VOCABULARY>
        The user has defined the following vocabulary terms. Prefer these specific \
        spellings and forms when they appear in the transcript. Do not invent \
        content or apply these terms outside their natural context.
        Terms: \(escapedList)
        </VOCABULARY>
        """
    }
}

extension VocabularySnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case terms
        case replacementRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terms = try container.decode([VocabularyTerm].self, forKey: .terms)
        replacementRules = try container.decode([VocabularyReplacementRule].self, forKey: .replacementRules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(terms, forKey: .terms)
        try container.encode(replacementRules, forKey: .replacementRules)
    }
}
