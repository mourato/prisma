import XCTest
@testable import MeetingAssistantCore

@MainActor
final class AppSettingsCloudSyncTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testCloudSnapshotApply_RestoresSyncedValues() {
        settings.systemPrompt = "System Prompt V1"
        settings.appAccentColor = .green
        settings.autoStartRecording = true
        settings.dictationAppRules = [
            DictationAppRule(bundleIdentifier: "com.apple.Safari", forceMarkdownOutput: true, outputLanguage: .english),
        ]

        let snapshot = settings.exportCloudSnapshotV1()

        settings.systemPrompt = "System Prompt V2"
        settings.appAccentColor = .orange
        settings.autoStartRecording = false
        settings.dictationAppRules = []

        settings.applyCloudSnapshotV1(snapshot, source: .cloud)

        XCTAssertEqual(settings.systemPrompt, "System Prompt V1")
        XCTAssertEqual(settings.appAccentColor, .green)
        XCTAssertTrue(settings.autoStartRecording)
        XCTAssertEqual(settings.dictationAppRules.count, 1)
        XCTAssertEqual(settings.dictationAppRules.first?.bundleIdentifier, "com.apple.Safari")
    }

    func testCloudSnapshotApply_DoesNotOverrideLocalOnlyFields() {
        settings.recordingsDirectory = "/tmp/sync-local-1"
        settings.microphoneWhenChargingUID = "local-mic-a"

        let snapshot = settings.exportCloudSnapshotV1()

        settings.recordingsDirectory = "/tmp/sync-local-2"
        settings.microphoneWhenChargingUID = "local-mic-b"

        settings.applyCloudSnapshotV1(snapshot, source: .cloud)

        XCTAssertEqual(settings.recordingsDirectory, "/tmp/sync-local-2")
        XCTAssertEqual(settings.microphoneWhenChargingUID, "local-mic-b")
    }
}
