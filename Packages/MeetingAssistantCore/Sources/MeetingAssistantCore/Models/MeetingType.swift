import Foundation

/// Represents the nature of the meeting to guide AI summarization strategies.
public enum MeetingType: String, CaseIterable, Codable, Sendable {
    /// The system will analyze the transcript to determine the best fit strategy
    case autodetect

    /// A balanced summary suitable for most standard business meetings
    case general

    /// Optimized for daily status updates, progress, and blockers
    case standup

    /// Focuses on design decisions, visual feedback, and critiques
    case designReview = "design_review"

    /// Focused on career development, personal feedback, and alignment
    case oneOnOne = "one_on_one"

    /// Optimized for technical talks, demos, or slides; focusing on key takeaways
    case presentation

    /// Focused on task allocation, timelines, and roadmap discussions
    case planning
}

public extension MeetingType {
    var displayName: String {
        switch self {
        case .autodetect: "Autodetect"
        case .general: "General"
        case .standup: "Standup"
        case .designReview: "Design Review"
        case .oneOnOne: "One-on-One"
        case .presentation: "Presentation"
        case .planning: "Planning"
        }
    }

    var iconName: String {
        switch self {
        case .autodetect: "sparkles"
        case .general: "bubble.left.and.bubble.right"
        case .standup: "figure.stand"
        case .designReview: "paintbrush"
        case .oneOnOne: "person.2"
        case .presentation: "tv"
        case .planning: "map"
        }
    }
}
