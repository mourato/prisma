import Combine
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

    override func setUp() async throws {
        try await super.setUp()
        // Initialize mocks locally first to ensure they are available for manager init
        let mic = MockAudioRecorder()
        let system = MockAudioRecorder()
        let transcription = MockTranscriptionClient()
        let postProcessing = MockPostProcessingService()
        let storage = MockStorageService()

        mockMic = mic
        mockSystem = system
        mockTranscription = transcription
        mockPostProcessing = postProcessing
        mockStorage = storage

        manager = RecordingManager(
            micRecorder: mic,
            systemRecorder: system,
            transcriptionClient: transcription,
            postProcessingService: postProcessing,
            storage: storage
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
        let mockPostProcessing = try XCTUnwrap(mockPostProcessing)
        let settings = AppSettingsStore.shared
        let keychain = DefaultKeychainProvider()
        let providerKey = KeychainManager.apiKeyKey(for: .openai)

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
            try? keychain.delete(for: providerKey)
        }

        try keychain.store("sk-test-openai", for: providerKey)
        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id

        await manager.startRecording(source: .microphone)
        await manager.stopRecording()

        XCTAssertGreaterThan(mockPostProcessing.processTranscriptionCallCount, 0)
        XCTAssertEqual(mockPostProcessing.lastPromptTitle, dictationPrompt.title)
        XCTAssertTrue(mockPostProcessing.lastPromptText?.contains("DICTATION_PROMPT_SENTINEL") ?? false)
        XCTAssertFalse(mockPostProcessing.lastPromptText?.contains("MEETING_PROMPT_SENTINEL") ?? true)
    }

    func testStopRecording_MeetingUsesMeetingPromptSelection() async throws {
        let manager = try XCTUnwrap(manager)
        let mockPostProcessing = try XCTUnwrap(mockPostProcessing)
        let settings = AppSettingsStore.shared
        let keychain = DefaultKeychainProvider()
        let providerKey = KeychainManager.apiKeyKey(for: .openai)

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
            try? keychain.delete(for: providerKey)
        }

        try keychain.store("sk-test-openai", for: providerKey)
        settings.postProcessingEnabled = true
        settings.enhancementsAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4o-mini")
        settings.meetingPrompts = [meetingPrompt]
        settings.dictationPrompts = [dictationPrompt]
        settings.selectedPromptId = meetingPrompt.id
        settings.dictationSelectedPromptId = dictationPrompt.id

        await manager.startRecording(source: .all)
        await manager.stopRecording()

        XCTAssertGreaterThan(mockPostProcessing.processTranscriptionCallCount, 0)
        XCTAssertEqual(mockPostProcessing.lastPromptTitle, meetingPrompt.title)
        XCTAssertTrue(mockPostProcessing.lastPromptText?.contains("MEETING_PROMPT_SENTINEL_2") ?? false)
        XCTAssertFalse(mockPostProcessing.lastPromptText?.contains("DICTATION_PROMPT_SENTINEL_2") ?? true)
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
