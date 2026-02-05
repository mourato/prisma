import XCTest
@testable import MeetingAssistantCore

@MainActor
final class TranscriptionDeliveryServiceTests: XCTestCase {
    
    // Save original settings to restore after tests
    private var originalAutoCopy: Bool = false
    private var originalAutoPaste: Bool = false
    
    override func setUp() async throws {
        originalAutoCopy = AppSettingsStore.shared.autoCopyTranscriptionToClipboard
        originalAutoPaste = AppSettingsStore.shared.autoPasteTranscriptionToActiveApp
        
        // Setup default test state: Auto copy ON, Auto paste OFF (to avoid accessibility checks)
        AppSettingsStore.shared.autoCopyTranscriptionToClipboard = true
        AppSettingsStore.shared.autoPasteTranscriptionToActiveApp = false
    }
    
    override func tearDown() async throws {
        AppSettingsStore.shared.autoCopyTranscriptionToClipboard = originalAutoCopy
        AppSettingsStore.shared.autoPasteTranscriptionToActiveApp = originalAutoPaste
    }
    
    func testDeliver_WithMeetingApp_DoesNotCopyToClipboard() {
        // Given
        let meeting = Meeting(app: .googleMeet)
        let transcription = Transcription(
            meeting: meeting,
            text: "Detected meeting text",
            rawText: "Detected meeting text"
        )
        
        NSPasteboard.general.clearContents()
        
        // When
        TranscriptionDeliveryService.deliver(transcription: transcription)
        
        // Then
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertNil(clipboardContent, "Clipboard should be empty for Meeting Apps")
    }
    
    func testDeliver_WithUnknownApp_CopiesToClipboard() {
        // Given
        let meeting = Meeting(app: .unknown)
        let transcription = Transcription(
            meeting: meeting,
            text: "Dictation text",
            rawText: "Dictation text"
        )
        
        NSPasteboard.general.clearContents()
        
        // When
        TranscriptionDeliveryService.deliver(transcription: transcription)
        
        // Then
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, "Dictation text", "Clipboard should contain text for Dictation (Unknown App)")
    }
    
    func testDeliver_WithImportedFile_DoesNotCopyToClipboard() {
        // Given
        let meeting = Meeting(app: .importedFile)
        let transcription = Transcription(
            meeting: meeting,
            text: "Imported text",
            rawText: "Imported text"
        )
        
        NSPasteboard.general.clearContents()
        
        // When
        TranscriptionDeliveryService.deliver(transcription: transcription)
        
        // Then
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertNil(clipboardContent, "Clipboard should be empty for Imported Files")
    }
}
