import Foundation
import MeetingAssistantCoreCommon

public enum PostProcessingError: LocalizedError {
    case noPromptSelected
    case noAPIConfigured
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case apiError(String)
    case emptyTranscription
    case transcriptionTooLong(Int)

    public var errorDescription: String? {
        switch self {
        case .noPromptSelected:
            "error.post_processing.no_prompt_selected".localized
        case .noAPIConfigured:
            "error.post_processing.no_api_configured".localized
        case .invalidURL:
            "error.post_processing.invalid_url".localized
        case let .requestFailed(error):
            "error.post_processing.request_failed".localized(with: error.localizedDescription)
        case .invalidResponse:
            "error.post_processing.invalid_response".localized
        case let .apiError(message):
            "error.post_processing.api_error".localized(with: message)
        case .emptyTranscription:
            "error.post_processing.empty_transcription".localized
        case let .transcriptionTooLong(count):
            "error.post_processing.transcription_too_long".localized(with: count)
        }
    }
}
