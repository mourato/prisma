import AVFoundation
import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log
import UserNotifications

// MARK: - Recording Control

public extension RecordingManager {
    func startCapture(purpose: CapturePurpose) async {
        let triggerLabel = purpose == .dictation ? "recording.start.dictation" : "recording.start.meeting"
        await startCapture(purpose: purpose, requestedAt: Date(), triggerLabel: triggerLabel)
    }

    func startCapture(
        purpose: CapturePurpose,
        requestedAt: Date,
        triggerLabel: String
    ) async {
        await startCapture(
            purpose: purpose,
            source: source(for: purpose),
            requestedAt: requestedAt,
            triggerLabel: triggerLabel
        )
    }

    /// Start recording audio for a meeting.
    /// - Parameters:
    ///   - source: The audio source to record.
    func startRecording(source: RecordingSource = .microphone) async {
        await startCapture(
            purpose: normalizedCapturePurpose(for: source),
            source: normalizedRecordingSource(for: source),
            requestedAt: Date(),
            triggerLabel: "recording.start.default"
        )
    }

    func startRecording(
        source: RecordingSource,
        requestedAt: Date,
        triggerLabel: String
    ) async {
        await startCapture(
            purpose: normalizedCapturePurpose(for: source),
            source: normalizedRecordingSource(for: source),
            requestedAt: requestedAt,
            triggerLabel: triggerLabel
        )
    }

    func startCapture(
        purpose: CapturePurpose,
        source: RecordingSource,
        requestedAt: Date,
        triggerLabel: String
    ) async {
        guard !isRecording else {
            AppLogger.info("Attempted to start recording but already recording", category: .recordingManager)
            return
        }

        guard await RecordingExclusivityCoordinator.shared.beginRecording(mode: exclusivityMode(for: purpose)) else {
            AppLogger.info("Recording start blocked by exclusivity coordinator", category: .recordingManager)
            return
        }

        currentCapturePurpose = purpose
        recordingSource = source
        activePostProcessingKernelMode = purpose == .dictation ? .dictation : .meeting
        isMeetingMicrophoneEnabled = purpose == .meeting
        dictationSessionOutputLanguageOverride = nil
        refreshPostProcessingReadinessWarning(for: purpose == .dictation ? .dictation : .meeting)

        // Prevent re-entrancy during async setup
        guard !isStartOperationInFlight else { return }
        isStartOperationInFlight = true
        defer { isStartOperationInFlight = false }

        let managerEntryAt = Date()
        activeStartTelemetry = RecordingStartTelemetry(
            triggerLabel: triggerLabel,
            source: source,
            requestedAt: requestedAt,
            managerEntryAt: managerEntryAt
        )
        isStartingRecording = true
        await Task.yield()
        SoundFeedbackService.shared.playRecordingStartSound()
        await Task.yield()

        do {
            let activeContext = try? await activeAppContextProvider.fetchActiveAppContext()
            let resolvedContext = captureContextResolver.resolveContext(
                for: purpose,
                activeContext: activeContext
            )
            let meeting = await applyAutomaticCalendarEventIfAvailable(
                to: createMeeting(
                    type: resolveMeetingType(),
                    purpose: purpose,
                    resolvedContext: resolvedContext
                )
            )
            dictationStartBundleIdentifier = purpose == .dictation ? resolvedContext.appBundleIdentifier : nil
            dictationStartURL = purpose == .dictation ? resolvedContext.activeBrowserURL : nil
            currentMeeting = meeting
            currentCapturePurpose = meeting.capturePurpose
            postProcessingContext = nil
            postProcessingContextItems = []
            restoreMeetingNotesIfNeeded(for: meeting.id)
            synchronizeMeetingNotesWithLinkedCalendarEventIfNeeded()
            isMeetingNotesPanelVisible = false

            // We only need one output URL because AudioRecorder handles mixing
            let audioURL = storage.createRecordingURL(for: meeting, type: .merged)
            setMergedAudioURL(audioURL)
            let outputURL = audioURL
            try await startRecorder(to: outputURL, source: source)

            let recorderStartAt = Date()
            markRecorderStartedAt(recorderStartAt)

            isRecording = true
            isStartingRecording = false
            meetingState = .recording // Sync state
            currentMeeting?.state = .recording // Sync entity state
            currentMeeting?.audioFilePath = outputURL.path

            startContextCaptureAfterRecordingStart(meetingID: meeting.id)

            AppLogger.info("Recording started successfully", category: .recordingManager, extra: [
                "app": meeting.appName,
                "url": outputURL.lastPathComponent,
                "source": source.rawValue,
            ])

        } catch {
            isStartingRecording = false
            await RecordingExclusivityCoordinator.shared.endRecording()
            postStartContextCaptureTask?.cancel()
            postStartContextCaptureTask = nil
            postProcessingContext = nil
            postProcessingContextItems = []
            activeStartTelemetry = nil
            await handleStartRecordingError(error)
        }
    }

    func noteIndicatorShownForStartIfNeeded() {
        guard var telemetry = activeStartTelemetry else { return }
        guard telemetry.indicatorShownAt == nil else { return }

        let now = Date()
        telemetry.indicatorShownAt = now
        activeStartTelemetry = telemetry

        let requestedToIndicatorMs = now.timeIntervalSince(telemetry.requestedAt) * 1_000
        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_requested_to_indicator_ms",
            value: requestedToIndicatorMs,
            unit: "ms"
        )

        if let recorderStartedAt = telemetry.recorderStartedAt {
            let recorderToIndicatorMs = now.timeIntervalSince(recorderStartedAt) * 1_000
            PerformanceMonitor.shared.reportMetric(
                name: "recording_start_recorder_to_indicator_ms",
                value: recorderToIndicatorMs,
                unit: "ms"
            )
        }

        AppLogger.debug(
            "Recording startup indicator is visible",
            category: .performance,
            extra: [
                "trace": telemetry.traceID,
                "trigger": telemetry.triggerLabel,
                "source": telemetry.source.rawValue,
            ]
        )
    }

    func overrideCurrentMeetingType(_ type: MeetingType) {
        guard isRecording, var meeting = currentMeeting else { return }
        meeting.type = type
        currentMeeting = meeting
    }

    func toggleMeetingMicrophone() async {
        await setMeetingMicrophoneEnabled(!isMeetingMicrophoneEnabled)
    }

    func setMeetingMicrophoneEnabled(_ isEnabled: Bool) async {
        guard currentCapturePurpose == .meeting, isRecording || isStartingRecording || isTranscribing else { return }
        isMeetingMicrophoneEnabled = isEnabled

        if let recorder = micRecorder as? AudioRecorder {
            recorder.setMeetingMicrophoneEnabled(isEnabled)
        }
    }

    private func exclusivityMode(for purpose: CapturePurpose) -> RecordingExclusivityCoordinator.RecordingMode {
        switch purpose {
        case .dictation:
            .dictation
        case .meeting:
            .meeting
        }
    }

    /// Stop recording and optionally transcribe.
    func stopRecording() async {
        await stopRecording(transcribe: true)
    }

    func stopRecording(transcribe: Bool = true) async {
        guard isRecording else {
            AppLogger.info("Attempted to stop recording but not recording", category: .recordingManager)
            return
        }

        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil
        isStartingRecording = false

        do {
            // Stop both recorders
            let micURL = await micRecorder.stopRecording()
            let sysURL = await systemRecorder.stopRecording()

            // Update meeting
            currentMeeting?.endTime = Date()

            // Issue #2: Start transcribing state BEFORE stopping recording state
            // to prevent the UI from hiding the indicator during audio merging gap.
            if transcribe {
                isTranscribing = true
                meetingState = .processing(.transcribing) // Sync state
                currentMeeting?.state = .processing(.transcribing) // Sync entity state
            } else {
                meetingState = .idle
                currentMeeting?.state = .completed
            }

            isRecording = false
            await RecordingExclusivityCoordinator.shared.endRecording()

            // Play stop recording sound feedback
            SoundFeedbackService.shared.playRecordingStopSound()

            AppLogger.info("Recording stopped", category: .recordingManager, extra: [
                "micURL": micURL?.lastPathComponent ?? "nil",
                "sysURL": sysURL?.lastPathComponent ?? "nil",
            ])

            let finalURL = try await processRecordedAudio(micURL: micURL, sysURL: sysURL)

            // Transcribe if requested
            if transcribe, let meeting = currentMeeting {
                await transcribeRecording(audioURL: finalURL, meeting: meeting)
            } else {
                postProcessingContext = nil
                postProcessingContextItems = []
                dictationSessionOutputLanguageOverride = nil
                clearMeetingNotesState(removePersistedValue: true)
                currentCapturePurpose = nil
                isMeetingMicrophoneEnabled = false
                currentMeeting = nil // Clear current meeting if done
                activeStartTelemetry = nil
                clearPostProcessingReadinessWarning()
            }

        } catch {
            AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
            lastError = error
            isRecording = false
            isTranscribing = false
            meetingState = .failed(error.localizedDescription) // Sync state
            currentMeeting?.state = .failed(error.localizedDescription) // Sync entity state
            await RecordingExclusivityCoordinator.shared.endRecording()
            postProcessingContext = nil
            postProcessingContextItems = []
            isStartingRecording = false
            dictationSessionOutputLanguageOverride = nil
            clearMeetingNotesState(removePersistedValue: true)
            currentCapturePurpose = nil
            isMeetingMicrophoneEnabled = false
            activeStartTelemetry = nil
            clearPostProcessingReadinessWarning()
        }
    }

    /// Cancel recording and discard audio files.
    func cancelRecording() async {
        guard isRecording || isStartingRecording else { return }

        if !isRecording {
            AppLogger.info("Cancelling recording during startup...", category: .recordingManager)
            _ = await micRecorder.stopRecording()
            _ = await systemRecorder.stopRecording()
            postStartContextCaptureTask?.cancel()
            postStartContextCaptureTask = nil
            isStartingRecording = false
            currentCapturePurpose = nil
            isMeetingMicrophoneEnabled = false
            clearMeetingNotesState(removePersistedValue: true)
            currentMeeting = nil
            postProcessingContext = nil
            postProcessingContextItems = []
            dictationSessionOutputLanguageOverride = nil
            activeStartTelemetry = nil
            clearPostProcessingReadinessWarning()
            await RecordingExclusivityCoordinator.shared.endRecording()
            SoundFeedbackService.shared.playRecordingCancelledSound()
            AppLogger.info("Recording startup cancelled", category: .recordingManager)
            return
        }

        AppLogger.info("Cancelling recording...", category: .recordingManager)

        // Stop recorders
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil

        // Cleanup temporary files
        await cleanupTemporaryFiles()

        // Also cleanup merged file if it exists
        if let mergedURL = await getMergedAudioURL() {
            try? FileManager.default.removeItem(at: mergedURL)
            setMergedAudioURL(nil)
        }

        // Reset state
        isRecording = false
        isStartingRecording = false
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        clearMeetingNotesState(removePersistedValue: true)
        currentMeeting = nil
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
        await RecordingExclusivityCoordinator.shared.endRecording()
        SoundFeedbackService.shared.playRecordingCancelledSound()

        AppLogger.info("Recording cancelled and files discarded", category: .recordingManager)
    }

    /// Transcribe an externally recorded audio file.
    /// - Parameter audioURL: Path to the audio file (m4a, mp3, wav).
    func transcribeExternalAudio(from audioURL: URL) async {
        guard !isTranscribing else {
            AppLogger.info("Already transcribing", category: .recordingManager)
            return
        }

        // Validate file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error(
                "Audio file not found for import",
                category: .recordingManager,
                extra: ["path": audioURL.path]
            )
            lastError = AudioImportError.fileNotFound
            return
        }

        // Validate file extension
        let validExtensions = ["m4a", "mp3", "wav"]
        guard validExtensions.contains(audioURL.pathExtension.lowercased()) else {
            AppLogger.error(
                "Unsupported audio format for import",
                category: .recordingManager,
                extra: ["extension": audioURL.pathExtension]
            )
            lastError = AudioImportError.unsupportedFormat
            return
        }

        // Create meeting record for imported file
        let meeting = Meeting(
            app: .importedFile,
            capturePurpose: .meeting,
            title: audioURL.deletingPathExtension().lastPathComponent,
            audioFilePath: audioURL.path
        )
        currentMeeting = meeting
        currentCapturePurpose = .meeting
        activePostProcessingKernelMode = .meeting
        isMeetingMicrophoneEnabled = false
        refreshPostProcessingReadinessWarning(for: .meeting)

        AppLogger.info(
            "Starting transcription for imported file",
            category: .recordingManager,
            extra: ["filename": audioURL.lastPathComponent]
        )
        await transcribeRecording(audioURL: audioURL, meeting: meeting)
    }

    /// Enable automatic recording when meetings are detected.
    internal func enableAutoRecording() {
        meetingDetector.startMonitoring()

        // Watch for detected meetings
        meetingDetector.$detectedMeeting
            .dropFirst()
            .removeDuplicates()
            .sink { @Sendable [weak self] detected in
                Task { @MainActor in
                    let isCurrentlyRecording = self?.isRecording ?? false
                    if detected != nil, !isCurrentlyRecording {
                        await self?.startCapture(purpose: .meeting)
                    } else if detected == nil, isCurrentlyRecording {
                        await self?.stopRecording()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Dictation Language

public extension RecordingManager {
    var effectiveDictationOutputLanguageForCurrentRecording: DictationOutputLanguage {
        if let override = dictationSessionOutputLanguageOverride {
            return override
        }

        let settings = AppSettingsStore.shared
        return matchingDictationAppRule(settings: settings)?.outputLanguage ?? .original
    }

    func setDictationSessionOutputLanguageOverride(_ language: DictationOutputLanguage?) {
        dictationSessionOutputLanguageOverride = language
    }
}

extension RecordingManager {
    private func resolveMeetingType() -> MeetingType {
        let settings = AppSettingsStore.shared
        return settings.meetingTypeAutoDetectEnabled ? .autodetect : .general
    }

    private func startRecorder(to url: URL, source: RecordingSource) async throws {
        AppLogger.debug(
            "Starting recorder",
            category: .recordingManager,
            extra: ["url": url.path, "source": source.rawValue]
        )

        if let recorder = micRecorder as? AudioRecorder {
            try await recorder.startRecording(to: url, source: source, retryCount: 0)
        } else {
            try await micRecorder.startRecording(to: url, retryCount: 0)
        }
    }

    private func createMeeting(
        type: MeetingType,
        purpose: CapturePurpose,
        resolvedContext: ResolvedCaptureContext
    ) -> Meeting {
        Meeting(
            app: purpose == .dictation ? .unknown : resolvedContext.meetingApp,
            capturePurpose: purpose,
            appBundleIdentifier: resolvedContext.appBundleIdentifier,
            appDisplayName: resolvedContext.appDisplayName,
            type: type,
            state: .recording
        )
    }

    private func normalizedCapturePurpose(for source: RecordingSource) -> CapturePurpose {
        switch source {
        case .microphone:
            .dictation
        case .system, .all:
            .meeting
        }
    }

    private func normalizedRecordingSource(for source: RecordingSource) -> RecordingSource {
        switch source {
        case .microphone:
            .microphone
        case .system, .all:
            .all
        }
    }

    private func source(for purpose: CapturePurpose) -> RecordingSource {
        switch purpose {
        case .dictation:
            .microphone
        case .meeting:
            .all
        }
    }

    private func handleStartRecordingError(_ error: Error) async {
        AppLogger.fault(
            "CRITICAL: Failed to start recording",
            category: .recordingManager,
            error: error,
            extra: ["state": "start_failed"]
        )
        isStartingRecording = false
        lastError = error
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil

        // Cleanup partial starts
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()

        currentMeeting = nil
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
    }
}
