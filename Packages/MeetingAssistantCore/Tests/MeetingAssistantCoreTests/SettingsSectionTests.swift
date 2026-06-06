@testable import MeetingAssistantCoreUI
import XCTest

final class SettingsSectionTests: XCTestCase {
    func testPrimarySections_IncludeIntegrationsBetweenAssistantAndMeetings() {
        XCTAssertEqual(
            SettingsSection.primarySections,
            [.metrics, .dictation, .assistant, .integrations, .meetings, .transcriptions]
        )
    }

    func testSettingsSections_OrderPlacesEnhancementsBeforeVocabulary() {
        XCTAssertEqual(
            SettingsSection.settingsSections,
            [.general, .models, .enhancements, .vocabulary, .audio, .permissions]
        )
    }
}
