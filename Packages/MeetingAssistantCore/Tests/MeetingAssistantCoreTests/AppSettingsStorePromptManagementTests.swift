import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsStorePromptManagementTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testEditingBuiltInDictationPromptKeepsSamePromptId() {
        let editedPrompt = PostProcessingPrompt(
            id: PostProcessingPrompt.cleanTranscription.id,
            title: "Edited Clean Prompt",
            promptText: "Edited text",
            icon: "text.badge.checkmark",
            description: "Edited description",
            isPredefined: false
        )

        settings.upsertDictationPrompt(editedPrompt)

        let promptsWithSameId = settings.dictationAvailablePrompts.filter { $0.id == editedPrompt.id }
        XCTAssertEqual(promptsWithSameId.count, 1)
        XCTAssertEqual(promptsWithSameId.first?.promptText, "Edited text")
    }

    func testDeletingBuiltInDictationPromptRemovesItFromAvailablePrompts() {
        settings.deleteDictationPrompt(id: PostProcessingPrompt.cleanTranscription.id)

        XCTAssertFalse(settings.dictationAvailablePrompts.contains { $0.id == PostProcessingPrompt.cleanTranscription.id })
    }

    func testDeletingAndEditingBuiltInMeetingPromptRestoresEditedPrompt() {
        settings.deleteMeetingPrompt(id: PostProcessingPrompt.standup.id)

        XCTAssertFalse(settings.meetingAvailablePrompts.contains { $0.id == PostProcessingPrompt.standup.id })

        let editedPrompt = PostProcessingPrompt(
            id: PostProcessingPrompt.standup.id,
            title: "Standup Custom",
            promptText: "Custom standup instructions",
            icon: "figure.stand",
            description: "Custom description",
            isPredefined: false
        )

        settings.upsertMeetingPrompt(editedPrompt)

        let restoredPrompt = settings.meetingAvailablePrompts.first(where: { $0.id == PostProcessingPrompt.standup.id })
        XCTAssertEqual(restoredPrompt?.title, "Standup Custom")
        XCTAssertEqual(restoredPrompt?.promptText, "Custom standup instructions")
    }

    func testMeetingNoPostProcessingSelection_DisablesPromptResolution() {
        settings.selectedPromptId = AppSettingsStore.noPostProcessingPromptId

        XCTAssertTrue(settings.isMeetingPostProcessingDisabled)
        XCTAssertNil(settings.selectedPrompt)
    }

    func testDictationNoPostProcessingSelection_DisablesPromptResolution() {
        settings.dictationSelectedPromptId = AppSettingsStore.noPostProcessingPromptId

        XCTAssertTrue(settings.isDictationPostProcessingDisabled)
        XCTAssertNil(settings.selectedDictationPrompt)
    }

    func testMeetingSummaryOutputLanguage_DefaultsToOriginal() {
        XCTAssertEqual(settings.meetingSummaryOutputLanguage, .original)
    }
}
