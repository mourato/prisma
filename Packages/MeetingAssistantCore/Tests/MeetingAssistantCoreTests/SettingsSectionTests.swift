@testable import MeetingAssistantCoreUI
import XCTest

final class SettingsSectionTests: XCTestCase {
    func testSettingsSections_OrderPlacesEnhancementsBeforeVocabulary() {
        XCTAssertEqual(
            SettingsSection.settingsSections,
            [.general, .models, .enhancements, .vocabulary, .audio, .permissions]
        )
    }
}
