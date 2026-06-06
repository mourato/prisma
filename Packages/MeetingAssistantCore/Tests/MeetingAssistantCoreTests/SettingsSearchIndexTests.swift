@testable import MeetingAssistantCoreUI
import XCTest

final class SettingsSearchIndexTests: XCTestCase {
    func testNormalizedRemovesDiacriticsAndCase() {
        let normalized = SettingsSearchIndex.normalized("Transcrição")

        XCTAssertEqual(normalized, "transcricao")
    }

    func testSectionMappingRoutesMeetingsKeysToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.meetings.template")

        XCTAssertEqual(section, .meetings)
    }

    func testResultsIncludeAudioSectionForAudioQuery() {
        let results = SettingsSearchIndex.results(for: "audio")

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: { $0.section == .audio }))
        XCTAssertTrue(results.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    func testSectionMappingRoutesIntegrationKeysToIntegrationsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.integrations.header_desc")

        XCTAssertEqual(section, .integrations)
    }

    func testSectionMappingRoutesMeetingCapabilityKeyToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.capabilities.meeting_transcription")

        XCTAssertEqual(section, .meetings)
    }

    func testSectionMappingRoutesIntegrationCapabilityKeyToIntegrationsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.capabilities.assistant_integrations")

        XCTAssertEqual(section, .integrations)
    }

    func testSectionMappingRoutesStylesKeysToDictationSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.styles.title")

        XCTAssertEqual(section, .dictation)
    }

    func testSectionMappingKeepsGeneralAudioFormatInGeneralSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_format")

        XCTAssertEqual(section, .general)
    }

    func testSectionMappingRoutesAudioDeviceKeyToAudioSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.general.audio_devices")

        XCTAssertEqual(section, .audio)
    }

    func testEverySearchableKeyMapsToASection() {
        for key in SettingsSearchIndex.searchableKeys {
            XCTAssertNotNil(
                SettingsSearchIndex.section(forLocalizationKey: key),
                "Key should map to a section: \(key)"
            )
        }
    }

    func testEmptyQueryReturnsNoResults() {
        XCTAssertTrue(SettingsSearchIndex.results(for: "   ").isEmpty)
    }
}
