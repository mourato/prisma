import XCTest
@testable import MeetingAssistantCore

// Mock for PasteboardService
final class MockPasteboardService: PasteboardServiceProtocol {
    var storedString: String?

    func clearContents() {
        storedString = nil
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) {
        storedString = string
    }
}

// Mock for DeliverySettingsConfig
struct MockDeliverySettings: DeliverySettingsConfig {
    var autoCopyTranscriptionToClipboard: Bool
    var autoPasteTranscriptionToActiveApp: Bool
}

@MainActor
final class TranscriptionDeliveryServiceTests: XCTestCase {

    // Constants to avoid magic strings
    private let kMeetingText = "Detected meeting text"
    private let kDictationText = "Dictation text"
    private let kImportedText = "Imported text"

    private var mockPasteboard: MockPasteboardService!

    override func setUp() async throws {
        mockPasteboard = MockPasteboardService()
    }

    func testDeliver_WithMeetingApp_DoesNotCopyToClipboard() {
        // Given
        let meeting = Meeting(app: .googleMeet)
        let transcription = Transcription(
            meeting: meeting,
            text: kMeetingText,
            rawText: kMeetingText
        )
        let settings = MockDeliverySettings(
            autoCopyTranscriptionToClipboard: true,
            autoPasteTranscriptionToActiveApp: false
        )

        // When
        TranscriptionDeliveryService.deliver(
            transcription: transcription,
            settings: settings,
            pasteboard: mockPasteboard
        )

        // Then
        XCTAssertNil(mockPasteboard.storedString, "Clipboard should be empty for Meeting Apps")
    }

    func testDeliver_IsDictation_CopiesToClipboard() {
        // Given
        let meeting = Meeting(app: .unknown)
        let transcription = Transcription(
            meeting: meeting,
            text: kDictationText,
            rawText: kDictationText
        )
        let settings = MockDeliverySettings(
            autoCopyTranscriptionToClipboard: true,
            autoPasteTranscriptionToActiveApp: false
        )

        // When
        TranscriptionDeliveryService.deliver(
            transcription: transcription,
            settings: settings,
            pasteboard: mockPasteboard
        )

        // Then
        XCTAssertEqual(mockPasteboard.storedString, kDictationText, "Clipboard should contain text for Dictation")
    }

    func testDeliver_WithImportedFile_DoesNotCopyToClipboard() {
        // Given
        let meeting = Meeting(app: .importedFile)
        let transcription = Transcription(
            meeting: meeting,
            text: kImportedText,
            rawText: kImportedText
        )
        let settings = MockDeliverySettings(
            autoCopyTranscriptionToClipboard: true,
            autoPasteTranscriptionToActiveApp: false
        )

        // When
        TranscriptionDeliveryService.deliver(
            transcription: transcription,
            settings: settings,
            pasteboard: mockPasteboard
        )

        // Then
        XCTAssertNil(mockPasteboard.storedString, "Clipboard should be empty for Imported Files")
    }

    func testDeliver_SettingsDisabled_DoesNotCopyToClipboard() {
        // Given
        let meeting = Meeting(app: .unknown)
        let transcription = Transcription(
            meeting: meeting,
            text: kDictationText,
            rawText: kDictationText
        )
        let settings = MockDeliverySettings(
            autoCopyTranscriptionToClipboard: false,
            autoPasteTranscriptionToActiveApp: false
        )

        // When
        TranscriptionDeliveryService.deliver(
            transcription: transcription,
            settings: settings,
            pasteboard: mockPasteboard
        )

        // Then
        XCTAssertNil(mockPasteboard.storedString, "Clipboard should be empty when settings are disabled")
    }
}
