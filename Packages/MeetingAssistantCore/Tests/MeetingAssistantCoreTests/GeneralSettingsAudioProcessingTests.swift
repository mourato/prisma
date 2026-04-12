import XCTest
@testable import MeetingAssistantCore

@MainActor
final class GeneralSettingsAudioProcessingTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testSilenceRemovalSettingIsPersistedThroughViewModelReload() {
        let firstViewModel = GeneralSettingsViewModel(settingsStore: settings)
        firstViewModel.removeSilenceBeforeProcessing = true

        let reloadedViewModel = GeneralSettingsViewModel(settingsStore: settings)

        XCTAssertTrue(settings.removeSilenceBeforeProcessing)
        XCTAssertTrue(reloadedViewModel.removeSilenceBeforeProcessing)
    }

    func testAudioDuckingSettingsArePersistedThroughViewModelReload() {
        let firstViewModel = GeneralSettingsViewModel(settingsStore: settings)
        firstViewModel.audioDuckingEnabled = true
        firstViewModel.audioDuckingLevelPercent = 28

        let reloadedViewModel = GeneralSettingsViewModel(settingsStore: settings)

        XCTAssertTrue(settings.audioDuckingEnabled)
        XCTAssertEqual(settings.audioDuckingLevelPercent, 28)
        XCTAssertTrue(reloadedViewModel.audioDuckingEnabled)
        XCTAssertEqual(reloadedViewModel.audioDuckingLevelPercent, 28)
    }
}
