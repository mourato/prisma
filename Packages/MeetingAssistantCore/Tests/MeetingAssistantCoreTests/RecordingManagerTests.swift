import Combine
import CryptoKit
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class RecordingManagerTests: XCTestCase {
    var manager: RecordingManager?
    var mockMic: MockAudioRecorder?
    var mockSystem: MockAudioRecorder?
    var mockTranscription: MockTranscriptionClient?
    var mockPostProcessing: MockPostProcessingService?
    var mockStorage: MockStorageService?
    var mockActiveAppContextProvider: MockActiveAppContextProvider?
    var mockCaptureContextResolver: MockCaptureContextResolver?
    var meetingNotesRichTextStore: MeetingNotesRichTextStore?
    var meetingNotesMarkdownStore: MeetingNotesMarkdownDocumentStore?
    var userDefaults: UserDefaults?
    var suiteName: String?
    var markdownRootDirectoryURL: URL?

    override func setUp() async throws {
        try await super.setUp()
        // Initialize mocks locally first to ensure they are available for manager init
        let mic = MockAudioRecorder()
        let system = MockAudioRecorder()
        let transcription = MockTranscriptionClient()
        let postProcessing = MockPostProcessingService()
        let storage = MockStorageService()
        let activeAppContextProvider = MockActiveAppContextProvider()
        let captureContextResolver = MockCaptureContextResolver()
        let suiteName = "RecordingManagerTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test UserDefaults suite")
            return
        }
        let richTextStore = MeetingNotesRichTextStore(userDefaults: userDefaults)
        let markdownRootDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-manager-markdown-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: markdownRootDirectoryURL, withIntermediateDirectories: true)
        let markdownStore = MeetingNotesMarkdownDocumentStore(
            userDefaults: userDefaults,
            rootDirectoryURL: markdownRootDirectoryURL
        )

        mockMic = mic
        mockSystem = system
        mockTranscription = transcription
        mockPostProcessing = postProcessing
        mockStorage = storage
        mockActiveAppContextProvider = activeAppContextProvider
        mockCaptureContextResolver = captureContextResolver
        meetingNotesRichTextStore = richTextStore
        meetingNotesMarkdownStore = markdownStore
        self.userDefaults = userDefaults
        self.suiteName = suiteName
        self.markdownRootDirectoryURL = markdownRootDirectoryURL

        manager = RecordingManager(
            micRecorder: mic,
            systemRecorder: system,
            transcriptionClient: transcription,
            postProcessingService: postProcessing,
            storage: storage,
            activeAppContextProvider: activeAppContextProvider,
            captureContextResolver: captureContextResolver,
            meetingNotesRichTextStore: richTextStore,
            meetingNotesMarkdownStore: markdownStore,
            apiKeyExists: { _ in true }
        )
    }

    override func tearDown() async throws {
        if let manager, manager.isRecording {
            await manager.cancelRecording()
        }

        await RecordingExclusivityCoordinator.shared.endRecording()
        await RecordingExclusivityCoordinator.shared.endAssistant()

        manager = nil
        mockMic = nil
        mockSystem = nil
        mockTranscription = nil
        mockPostProcessing = nil
        mockStorage = nil
        mockActiveAppContextProvider = nil
        mockCaptureContextResolver = nil
        meetingNotesRichTextStore = nil
        meetingNotesMarkdownStore = nil
        if let suiteName {
            userDefaults?.removePersistentDomain(forName: suiteName)
        }
        if let markdownRootDirectoryURL {
            try? FileManager.default.removeItem(at: markdownRootDirectoryURL)
        }
        userDefaults = nil
        suiteName = nil
        markdownRootDirectoryURL = nil
        try await super.tearDown()
    }

    // MARK: - Basic Tests

    func testInitialization() throws {
        let manager = try XCTUnwrap(manager)
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isTranscribing)
    }

    func testStorageServiceUsage() async throws {
        let manager = try XCTUnwrap(manager)
        let mockStorage = try XCTUnwrap(mockStorage)

        await manager.startRecording()
        XCTAssertTrue(mockStorage.createRecordingURLCalled)
    }

    func testCheckPermissions_WhenBothGranted() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.checkPermission()

        XCTAssertTrue(manager.hasRequiredPermissions)
    }

    func testCheckPermissions_WhenOneDenied() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = false

        await manager.checkPermission(for: .all)

        XCTAssertFalse(manager.hasRequiredPermissions)
    }

    func testStartRecording_Success() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()

        XCTAssertTrue(manager.isRecording)
        XCTAssertTrue(mockMic.startRecordingCalled)
    }

    func testStartRecording_FailsIfAlreadyRecording() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)

        await manager.startRecording()

        mockMic.startRecordingCalled = false

        await manager.startRecording()

        XCTAssertFalse(mockMic.startRecordingCalled)
    }

    func testSharedRecorderState_DoesNotMarkRecordingWhenManagerHasNoOwnedCapture() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)

        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentCapturePurpose)

        mockMic.isRecording = true
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertFalse(manager.isRecording)
    }

    func testShouldApplyEnhancementsPostProcessing_ReturnsFalseWhenModelIsMissing() {
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalSelection = settings.enhancementsAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalSelection
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: " ")

        let shouldApply = RecordingManager.shouldApplyEnhancementsPostProcessing(
            settings: settings,
            kernelMode: .meeting,
            apiKeyExists: { _ in true }
        )

        XCTAssertFalse(shouldApply)
    }

    func testShouldApplyEnhancementsPostProcessing_ReturnsTrueWhenConfigurationIsReady() {
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalSelection = settings.enhancementsAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalSelection
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")

        let shouldApply = RecordingManager.shouldApplyEnhancementsPostProcessing(
            settings: settings,
            kernelMode: .meeting,
            apiKeyExists: { _ in true }
        )

        XCTAssertTrue(shouldApply)
    }

    func testShouldApplyEnhancementsPostProcessing_AllowsDictationWhenConfigurationIsReady() {
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection
        let originalDictationSelection = settings.enhancementsDictationAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            settings.enhancementsDictationAISelection = originalDictationSelection
        }

        settings.postProcessingEnabled = true
        settings.enhancementsDictationAISelection = EnhancementsAISelection(
            provider: .openai,
            selectedModel: "gpt-4o-mini"
        )

        let shouldApply = RecordingManager.shouldApplyEnhancementsPostProcessing(
            settings: settings,
            kernelMode: .dictation,
            apiKeyExists: { _ in true }
        )

        XCTAssertTrue(shouldApply)
    }

    func testRefreshPostProcessingReadinessWarning_SetsIssueForMeetingMode() throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            manager.clearPostProcessingReadinessWarning()
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: " ")

        manager.refreshPostProcessingReadinessWarning(for: .meeting, settings: settings, apiKeyExists: { _ in true })

        XCTAssertEqual(manager.postProcessingReadinessWarningIssue, .missingModel)
        XCTAssertEqual(manager.postProcessingReadinessWarningMode, .meeting)
    }

    func testRefreshPostProcessingReadinessWarning_SetsIssueForAssistantMode() throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalDictationSelection = settings.enhancementsDictationAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsDictationAISelection = originalDictationSelection
            manager.clearPostProcessingReadinessWarning()
        }

        settings.postProcessingEnabled = true
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "")

        manager.refreshPostProcessingReadinessWarning(for: .assistant, settings: settings, apiKeyExists: { _ in true })

        XCTAssertEqual(manager.postProcessingReadinessWarningIssue, .missingModel)
        XCTAssertEqual(manager.postProcessingReadinessWarningMode, .assistant)
    }

    func testMeetingNotes_AutosaveAndRestore_ByMeetingID() throws {
        let manager = try XCTUnwrap(manager)
        let meetingID = UUID()
        manager.currentCapturePurpose = .meeting
        manager.currentMeeting = Meeting(id: meetingID, app: .zoom, capturePurpose: .meeting)
        let richData = Data([0x7B, 0x5C, 0x72, 0x74, 0x66])

        manager.updateMeetingNotes(MeetingNotesContent(plainText: "Important note", richTextRTFData: richData))
        XCTAssertTrue(markdownMeetingFileExists(for: meetingID))
        manager.currentMeetingNotesText = ""
        manager.currentMeetingNotesRichTextData = nil
        manager.restoreMeetingNotesIfNeeded(for: meetingID)

        XCTAssertEqual(manager.currentMeetingNotesText, "Important note")
        XCTAssertEqual(manager.currentMeetingNotesRichTextData, richData)

        manager.clearMeetingNotesState(removePersistedValue: true)
        manager.currentMeeting = Meeting(id: meetingID, app: .zoom, capturePurpose: .meeting)
        manager.restoreMeetingNotesIfNeeded(for: meetingID)
        XCTAssertEqual(manager.currentMeetingNotesText, "")
        XCTAssertNil(manager.currentMeetingNotesRichTextData)
    }

    func testCalendarEventNotes_SaveAndRestore_ByEventIdentifier() throws {
        let manager = try XCTUnwrap(manager)
        let eventIdentifier = "event-\(UUID().uuidString)"
        let richData = Data([0x7B, 0x5C, 0x72, 0x74, 0x66])

        manager.updateCalendarEventNotes(
            MeetingNotesContent(plainText: "Event note", richTextRTFData: richData),
            for: eventIdentifier
        )
        XCTAssertTrue(markdownEventFileExists(for: eventIdentifier))
        XCTAssertEqual(manager.loadCalendarEventNotesText(for: eventIdentifier), "Event note")
        XCTAssertEqual(manager.loadCalendarEventNotesContent(for: eventIdentifier).richTextRTFData, richData)

        manager.updateCalendarEventNotesText("   ", for: eventIdentifier)
        XCTAssertEqual(manager.loadCalendarEventNotesText(for: eventIdentifier), "")
        XCTAssertNil(manager.loadCalendarEventNotesContent(for: eventIdentifier).richTextRTFData)
    }

    func testUpdateCalendarEventNotes_SyncsToLinkedActiveMeeting() throws {
        let manager = try XCTUnwrap(manager)
        let meetingID = UUID()
        let eventIdentifier = "event-\(UUID().uuidString)"
        let linkedEvent = MeetingCalendarEventSnapshot(
            eventIdentifier: eventIdentifier,
            title: "Design review",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3_600)
        )
        manager.currentCapturePurpose = .meeting
        manager.currentMeeting = Meeting(
            id: meetingID,
            app: .zoom,
            capturePurpose: .meeting,
            linkedCalendarEvent: linkedEvent
        )

        manager.updateCalendarEventNotesText("Synced from event", for: eventIdentifier)

        XCTAssertEqual(manager.currentMeetingNotesText, "Synced from event")
        manager.currentMeetingNotesText = ""
        manager.restoreMeetingNotesIfNeeded(for: meetingID)
        XCTAssertEqual(manager.currentMeetingNotesText, "Synced from event")

        manager.updateCalendarEventNotesText("   ", for: eventIdentifier)
        manager.clearMeetingNotesState(removePersistedValue: true)
    }

    func testUpdateMeetingNotes_SyncsToLinkedCalendarEvent() throws {
        let manager = try XCTUnwrap(manager)
        let meetingID = UUID()
        let eventIdentifier = "event-\(UUID().uuidString)"
        let linkedEvent = MeetingCalendarEventSnapshot(
            eventIdentifier: eventIdentifier,
            title: "Team sync",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3_600)
        )
        manager.currentCapturePurpose = .meeting
        manager.currentMeeting = Meeting(
            id: meetingID,
            app: .zoom,
            capturePurpose: .meeting,
            linkedCalendarEvent: linkedEvent
        )

        manager.updateMeetingNotesText("Synced from meeting")

        XCTAssertEqual(manager.loadCalendarEventNotesText(for: eventIdentifier), "Synced from meeting")

        manager.updateMeetingNotesText("   ")
        manager.updateCalendarEventNotesText("   ", for: eventIdentifier)
    }

    func testLinkCurrentMeeting_MergesEventAndMeetingNotes_EventFirst() async throws {
        let manager = try XCTUnwrap(manager)
        try await Task.sleep(for: .milliseconds(50))
        let meetingID = UUID()
        let eventIdentifier = "event-\(UUID().uuidString)"
        manager.currentCapturePurpose = .meeting
        manager.currentMeeting = Meeting(id: meetingID, app: .zoom, capturePurpose: .meeting)

        manager.updateMeetingNotes(
            MeetingNotesContent(plainText: "Meeting note", richTextRTFData: Data([0x01, 0x02]))
        )
        manager.updateCalendarEventNotes(
            MeetingNotesContent(plainText: "Event note", richTextRTFData: Data([0x03, 0x04])),
            for: eventIdentifier
        )
        XCTAssertEqual(manager.loadCalendarEventNotesText(for: eventIdentifier), "Event note")

        let linkedEvent = MeetingCalendarEventSnapshot(
            eventIdentifier: eventIdentifier,
            title: "Merged notes check",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3_600)
        )
        manager.linkCurrentMeeting(to: linkedEvent)

        let expected = "Event note\n\n---\n\nMeeting note"
        XCTAssertEqual(manager.currentMeetingNotesText, expected)
        XCTAssertEqual(manager.loadCalendarEventNotesText(for: eventIdentifier), expected)
        XCTAssertNil(manager.currentMeetingNotesRichTextData)
        XCTAssertNil(manager.loadCalendarEventNotesContent(for: eventIdentifier).richTextRTFData)

        manager.currentMeetingNotesText = ""
        manager.restoreMeetingNotesIfNeeded(for: meetingID)
        XCTAssertEqual(manager.currentMeetingNotesText, expected)

        manager.updateMeetingNotesText("   ")
        manager.updateCalendarEventNotesText("   ", for: eventIdentifier)
    }

    func testMergedPostProcessingInput_IncludesMeetingNotesBlock() throws {
        let manager = try XCTUnwrap(manager)
        let qualityProfile = TranscriptionQualityProfile(
            normalizedTextForIntelligence: "Normalized text",
            overallConfidence: 0.9,
            containsUncertainty: false,
            markers: []
        )

        let input = manager.mergedPostProcessingInput(
            transcriptionText: qualityProfile.normalizedTextForIntelligence,
            qualityProfile: qualityProfile,
            context: nil,
            meetingNotes: "User highlight",
            includeQualityMetadata: true
        )

        XCTAssertTrue(input.contains("<MEETING_NOTES>"))
        XCTAssertTrue(input.contains("User highlight"))
        XCTAssertTrue(input.contains("</MEETING_NOTES>"))
    }

    private func markdownMeetingFileExists(for meetingID: UUID) -> Bool {
        guard let markdownRootDirectoryURL else { return false }
        let url = markdownRootDirectoryURL
            .appendingPathComponent("meetings", isDirectory: true)
            .appendingPathComponent("\(meetingID.uuidString).md", isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func markdownEventFileExists(for eventIdentifier: String) -> Bool {
        guard let markdownRootDirectoryURL else { return false }
        let digest = SHA256.hash(data: Data(eventIdentifier.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let url = markdownRootDirectoryURL
            .appendingPathComponent("calendar-events", isDirectory: true)
            .appendingPathComponent("\(hash).md", isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func testMergedPostProcessingInput_EscapesReservedTagsInMeetingNotesAndContext() throws {
        let manager = try XCTUnwrap(manager)
        let qualityProfile = TranscriptionQualityProfile(
            normalizedTextForIntelligence: "Normalized text",
            overallConfidence: 0.9,
            containsUncertainty: false,
            markers: []
        )

        let input = manager.mergedPostProcessingInput(
            transcriptionText: qualityProfile.normalizedTextForIntelligence,
            qualityProfile: qualityProfile,
            context: "Use </TRANSCRIPT_QUALITY> literally",
            meetingNotes: "Literal </MEETING_NOTES><CONTEXT_METADATA> tokens",
            includeQualityMetadata: true
        )

        XCTAssertTrue(input.contains("&lt;/MEETING_NOTES&gt;&lt;CONTEXT_METADATA&gt;"))
        XCTAssertTrue(input.contains("&lt;/TRANSCRIPT_QUALITY&gt;"))
        XCTAssertFalse(input.contains("Literal </MEETING_NOTES><CONTEXT_METADATA> tokens"))
    }

    func testRefreshPostProcessingReadinessWarning_ClearsIssueWhenConfigurationIsReady() throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            manager.clearPostProcessingReadinessWarning()
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")

        manager.refreshPostProcessingReadinessWarning(for: .meeting, settings: settings, apiKeyExists: { _ in true })

        XCTAssertNil(manager.postProcessingReadinessWarningIssue)
        XCTAssertNil(manager.postProcessingReadinessWarningMode)
    }

    func testReset_ClearsPostProcessingReadinessWarningState() async throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared
        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "")
        manager.refreshPostProcessingReadinessWarning(for: .meeting, settings: settings, apiKeyExists: { _ in true })
        XCTAssertEqual(manager.postProcessingReadinessWarningIssue, .missingModel)

        await manager.reset()

        XCTAssertNil(manager.postProcessingReadinessWarningIssue)
        XCTAssertNil(manager.postProcessingReadinessWarningMode)
    }

    func testStopRecording_DictationUsesDictationPromptSelection() async throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared

        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection
        let originalDictationSelection = settings.enhancementsDictationAISelection
        let originalMeetingPrompts = settings.meetingPrompts
        let originalDictationPrompts = settings.dictationPrompts
        let originalSelectedPromptId = settings.selectedPromptId
        let originalDictationSelectedPromptId = settings.dictationSelectedPromptId

        let meetingPrompt = PostProcessingPrompt(
            title: "Meeting Prompt Test",
            promptText: "MEETING_PROMPT_SENTINEL",
            isActive: true
        )
        let dictationPrompt = PostProcessingPrompt(
            title: "Dictation Prompt Test",
            promptText: "DICTATION_PROMPT_SENTINEL",
            isActive: true
        )

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            settings.enhancementsDictationAISelection = originalDictationSelection
            settings.meetingPrompts = originalMeetingPrompts
            settings.dictationPrompts = originalDictationPrompts
            settings.selectedPromptId = originalSelectedPromptId
            settings.dictationSelectedPromptId = originalDictationSelectedPromptId
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id

        await manager.startRecording(source: .microphone)
        XCTAssertTrue(manager.isRecording)

        let meeting = Meeting(app: .unknown)
        let configuration = manager.debugResolvePostProcessingConfiguration(meeting: meeting, settings: settings)

        XCTAssertEqual(configuration.kernelMode, .dictation)
        XCTAssertTrue(configuration.applyPostProcessing)
        XCTAssertEqual(configuration.promptId, dictationPrompt.id)
        XCTAssertEqual(configuration.promptTitle, dictationPrompt.title)

        await manager.cancelRecording()
    }

    func testStopRecording_MeetingUsesMeetingPromptSelection() async throws {
        let manager = try XCTUnwrap(manager)
        let settings = AppSettingsStore.shared

        let originalPostProcessing = settings.postProcessingEnabled
        let originalMeetingSelection = settings.enhancementsAISelection
        let originalDictationSelection = settings.enhancementsDictationAISelection
        let originalMeetingPrompts = settings.meetingPrompts
        let originalDictationPrompts = settings.dictationPrompts
        let originalSelectedPromptId = settings.selectedPromptId
        let originalDictationSelectedPromptId = settings.dictationSelectedPromptId

        let meetingPrompt = PostProcessingPrompt(
            title: "Meeting Prompt Test 2",
            promptText: "MEETING_PROMPT_SENTINEL_2",
            isActive: true
        )
        let dictationPrompt = PostProcessingPrompt(
            title: "Dictation Prompt Test 2",
            promptText: "DICTATION_PROMPT_SENTINEL_2",
            isActive: true
        )

        defer {
            settings.postProcessingEnabled = originalPostProcessing
            settings.enhancementsAISelection = originalMeetingSelection
            settings.enhancementsDictationAISelection = originalDictationSelection
            settings.meetingPrompts = originalMeetingPrompts
            settings.dictationPrompts = originalDictationPrompts
            settings.selectedPromptId = originalSelectedPromptId
            settings.dictationSelectedPromptId = originalDictationSelectedPromptId
        }

        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id

        await manager.startRecording(source: .all)
        XCTAssertTrue(manager.isRecording)

        let meeting = Meeting(app: .zoom)
        let configuration = manager.debugResolvePostProcessingConfiguration(meeting: meeting, settings: settings)

        XCTAssertEqual(configuration.kernelMode, .meeting)
        XCTAssertTrue(configuration.applyPostProcessing)
        XCTAssertEqual(configuration.promptId, meetingPrompt.id)
        XCTAssertEqual(configuration.promptTitle, meetingPrompt.title)

        await manager.cancelRecording()
    }

    // MARK: - Error Handling Tests

    func testStartRecording_FailsWhenSystemRecorderFails() async throws {
        // Given
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true
        mockMic.shouldFailStart = true

        // When
        do {
            try await mockMic.startRecording(to: URL(fileURLWithPath: "/tmp/test.m4a"), retryCount: 0)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then
            XCTAssertNotNil(error)
        }
    }

    func testStopRecording_HandlesErrorGracefully() async throws {
        // Given
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)

        mockMic.permissionGranted = true
        mockSystem.permissionGranted = true

        await manager.startRecording()

        // When - stopping should not throw even if cleanup fails
        await manager.stopRecording()

        // Then - should have stopped
        XCTAssertFalse(manager.isRecording)
    }

    func testTranscription_FailsWithInvalidURL() async throws {
        // Given
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/file.m4a")
        mockTranscription.shouldFailTranscription = true

        // When/Then
        do {
            _ = try await mockTranscription.transcribe(audioURL: invalidURL)
            XCTFail("Expected error for transcription failure")
        } catch {
            // Should fail when shouldFailTranscription is true
            XCTAssertNotNil(error)
        }
    }

    func testMockStorageService_LoadTranscriptions() async throws {
        // Given
        let mockStorage = try XCTUnwrap(mockStorage)

        let mockTranscription = Transcription(
            meeting: Meeting(app: .unknown),
            text: "Test transcription",
            rawText: "Test transcription",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "pt",
            modelName: "test-model"
        )
        mockStorage.mockTranscriptions = [mockTranscription]

        // When
        let transcriptions = try await mockStorage.loadTranscriptions()

        // Then
        XCTAssertEqual(transcriptions.count, 1)
        XCTAssertEqual(mockStorage.loadTranscriptionsCallCount, 1)
    }

    func testMockTranscriptionClient_CallTracking() async throws {
        // Given
        let mockTranscription = try XCTUnwrap(mockTranscription)
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        _ = try await mockTranscription.transcribe(audioURL: audioURL)

        // Then
        XCTAssertEqual(mockTranscription.transcribeCallCount, 1)
        XCTAssertEqual(mockTranscription.lastTranscribeAudioURL, audioURL)
    }

    func testMockAudioRecorder_CallTracking() async throws {
        // Given
        let mockMic = try XCTUnwrap(mockMic)
        let audioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // When
        try await mockMic.startRecording(to: audioURL, retryCount: 0)
        _ = await mockMic.stopRecording()

        // Then
        XCTAssertEqual(mockMic.startRecordingParams.count, 1)
        XCTAssertEqual(mockMic.startRecordingParams.first?.url, audioURL)
        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
    }
}
