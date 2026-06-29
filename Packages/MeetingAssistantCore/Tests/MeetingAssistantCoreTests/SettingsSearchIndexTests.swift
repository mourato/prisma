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
        let audioTitle = "settings.section.audio".localized
        guard audioTitle != "settings.section.audio" else { return }

        let results = SettingsSearchIndex.results(for: audioTitle)

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

    func testSectionMappingRoutesDictationModelSelectorToDictationSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.selector.dictation.title")

        XCTAssertEqual(section, .dictation)
    }

    func testSectionMappingRoutesMeetingModelSelectorToMeetingsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.selector.meeting.title")

        XCTAssertEqual(section, .meetings)
    }

    func testSectionMappingRoutesAIProviderSetupToModelsSection() {
        let section = SettingsSearchIndex.section(forLocalizationKey: "settings.enhancements.provider_models.title")

        XCTAssertEqual(section, .models)
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
