import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreInfrastructure

@MainActor
final class AppSettingsAudioDuckingTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testAudioDuckingSettingsPersistInUserDefaults() {
        settings.audioDuckingEnabled = true
        settings.audioDuckingLevelPercent = 22

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "audioDuckingEnabled"))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "audioDuckingLevelPercent"), 22)
    }

    func testAudioDuckingLevelIsClampedInStore() {
        settings.audioDuckingLevelPercent = 120
        XCTAssertEqual(settings.audioDuckingLevelPercent, 100)

        settings.audioDuckingLevelPercent = -5
        XCTAssertEqual(settings.audioDuckingLevelPercent, 0)
    }

    func testLoadAudioAndLanguageSettingsMigratesLegacyMuteWhenNewKeysMissing() {
        UserDefaults.standard.removeObject(forKey: "audioDuckingEnabled")
        UserDefaults.standard.removeObject(forKey: "audioDuckingLevelPercent")
        UserDefaults.standard.set(true, forKey: "muteOutputDuringRecording")

        let loaded = AppSettingsStore.loadAudioAndLanguageSettings()

        XCTAssertTrue(loaded.audioDuckingEnabled)
        XCTAssertEqual(loaded.audioDuckingLevelPercent, 0)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "audioDuckingEnabled"))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "audioDuckingLevelPercent"), 0)
    }

    func testLoadAudioAndLanguageSettingsKeepsExplicitNewValues() {
        UserDefaults.standard.set(false, forKey: "audioDuckingEnabled")
        UserDefaults.standard.set(44, forKey: "audioDuckingLevelPercent")
        UserDefaults.standard.set(true, forKey: "muteOutputDuringRecording")

        let loaded = AppSettingsStore.loadAudioAndLanguageSettings()

        XCTAssertFalse(loaded.audioDuckingEnabled)
        XCTAssertEqual(loaded.audioDuckingLevelPercent, 44)
    }

    func testLoadAudioAndLanguageSettingsUsesDefaultsWhenUnsetAndNoLegacyMute() {
        UserDefaults.standard.removeObject(forKey: "audioDuckingEnabled")
        UserDefaults.standard.removeObject(forKey: "audioDuckingLevelPercent")
        UserDefaults.standard.set(false, forKey: "muteOutputDuringRecording")

        let loaded = AppSettingsStore.loadAudioAndLanguageSettings()

        XCTAssertFalse(loaded.audioDuckingEnabled)
        XCTAssertEqual(loaded.audioDuckingLevelPercent, AppSettingsStore.defaultAudioDuckingLevelPercent)
    }
}
