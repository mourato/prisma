import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Transcription

extension RecordingManager {
    func transcribeRecording(audioURL: URL, meeting: Meeting) async {
        beginTranscriptionUIStateIfNeeded()

        let audioDuration = await getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            try await performHealthCheck()

            let settings = AppSettingsStore.shared
            let transcriptionStart = Date()
            let meetingEntity = makeMeetingEntity(meeting: meeting, audioDuration: audioDuration)
            let config = makeUseCaseConfig(meeting: meeting, settings: settings)
            let diarizationEnabledOverride = shouldEnableDiarization(
                for: meeting,
                preferCurrentRecordingSource: true
            )

            meetingState = .processing(.transcribing)

            let transcriptionEntity = try await transcribeAudioUseCase.execute(
                audioURL: audioURL,
                meeting: meetingEntity,
                inputSource: resolveInputSourceLabel(for: meeting),
                contextItems: config.postProcessingContextItems,
                vocabularyReplacementRules: settings.vocabularyReplacementRules,
                diarizationEnabledOverride: diarizationEnabledOverride,
                applyPostProcessing: config.applyPostProcessing,
                postProcessingPrompt: config.postProcessingPrompt,
                defaultPostProcessingPrompt: config.defaultPostProcessingPrompt,
                postProcessingModel: config.postProcessingModel,
                autoDetectMeetingType: config.autoDetectMeetingType,
                availablePrompts: config.availablePrompts,
                postProcessingContext: config.postProcessingContext,
                kernelMode: config.kernelMode,
                dictationStructuredPostProcessingEnabled: config.dictationStructuredPostProcessingEnabled
            )

            let transcription = convertToModel(transcriptionEntity, audioDuration: audioDuration, transcriptionStart: transcriptionStart)
            persistCurrentMeetingNotesForTranscription(transcription.id)

            meetingState = .processing(.generatingOutput)
            currentMeeting?.state = .completed

            TranscriptionDeliveryService.deliver(
                transcription: transcription,
                recordingSource: recordingSource
            )

            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: transcription)
            scheduleStatusReset()

            if settings.autoExportSummaries {
                await exportSummary(transcription: transcription)
            }
        } catch {
            handleTranscriptionError(error)
            meetingState = .failed(error.localizedDescription)
            currentMeeting?.state = .failed(error.localizedDescription)
        }

        isTranscribing = false
        isStartingRecording = false
        meetingState = .idle
        clearMeetingNotesState(removePersistedValue: true)
        currentMeeting = nil
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        activeStartTelemetry = nil
        postStartContextCaptureTask = nil
        clearPostProcessingReadinessWarning()
    }

    func beginTranscriptionUIStateIfNeeded() {
        guard !isTranscribing else { return }
        isTranscribing = true
        meetingState = .processing(.transcribing)
        currentMeeting?.state = .processing(.transcribing)
    }

    // MARK: - Entity Conversion

    func makeMeetingEntity(meeting: Meeting, audioDuration: Double?) -> MeetingEntity {
        var entity = MeetingEntity(
            id: meeting.id,
            app: DomainMeetingApp(rawValue: meeting.app.rawValue) ?? .unknown,
            capturePurpose: meeting.capturePurpose,
            appBundleIdentifier: meeting.appBundleIdentifier,
            appDisplayName: meeting.appDisplayName,
            title: meeting.title,
            linkedCalendarEvent: meeting.linkedCalendarEvent,
            startTime: meeting.startTime,
            endTime: meeting.endTime,
            audioFilePath: meeting.audioFilePath
        )

        if entity.endTime == nil, let audioDuration {
            entity.endTime = entity.startTime.addingTimeInterval(audioDuration)
        }

        return entity
    }

    func convertToModel(_ entity: TranscriptionEntity, audioDuration: Double?, transcriptionStart: Date) -> Transcription {
        Transcription(
            id: entity.id,
            meeting: Meeting(
                id: entity.meeting.id,
                app: MeetingApp(rawValue: entity.meeting.app.rawValue) ?? .unknown,
                capturePurpose: entity.meeting.capturePurpose,
                appBundleIdentifier: entity.meeting.appBundleIdentifier,
                appDisplayName: entity.meeting.appDisplayName,
                title: entity.meeting.title,
                linkedCalendarEvent: entity.meeting.linkedCalendarEvent,
                type: MeetingType(rawValue: entity.meetingType ?? "") ?? .general,
                startTime: entity.meeting.startTime,
                endTime: entity.meeting.endTime,
                audioFilePath: entity.meeting.audioFilePath
            ),
            contextItems: entity.contextItems,
            segments: entity.segments.map { Transcription.Segment(id: $0.id, speaker: $0.speaker, text: $0.text, startTime: $0.startTime, endTime: $0.endTime) },
            text: entity.text,
            rawText: entity.rawText,
            processedContent: entity.processedContent,
            canonicalSummary: entity.canonicalSummary,
            qualityProfile: entity.qualityProfile,
            postProcessingPromptId: entity.postProcessingPromptId,
            postProcessingPromptTitle: entity.postProcessingPromptTitle,
            language: entity.language,
            createdAt: entity.createdAt,
            modelName: entity.modelName,
            inputSource: entity.inputSource,
            transcriptionDuration: entity.transcriptionDuration,
            postProcessingDuration: entity.postProcessingDuration,
            postProcessingModel: entity.postProcessingModel,
            meetingType: entity.meetingType
        )
    }

    // MARK: - Health Check & Transcription

    func performHealthCheck() async throws {
        transcriptionStatus.updateProgress(phase: .preparing)
        let isHealthy = try await transcriptionClient.healthCheck()
        guard isHealthy else {
            throw TranscriptionError.serviceUnavailable
        }
    }

    func performTranscription(
        audioURL: URL,
        diarizationEnabledOverride: Bool? = nil
    ) async throws -> TranscriptionResponse {
        transcriptionStatus.updateProgress(phase: .processing, percentage: Constants.processingProgress)
        let onProgress: @Sendable (Double) -> Void = { [weak self] percentage in
            Task { @MainActor in
                self?.transcriptionStatus.updateProgress(phase: .processing, percentage: percentage)
            }
        }

        if let diarizationAwareClient = transcriptionClient as? any TranscriptionServiceDiarizationOverride {
            return try await diarizationAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride
            )
        }

        return try await transcriptionClient.transcribe(
            audioURL: audioURL,
            onProgress: onProgress
        )
    }

    func shouldEnableDiarization(
        for meeting: Meeting,
        preferCurrentRecordingSource: Bool = false
    ) -> Bool {
        if meeting.app == .importedFile {
            return false
        }

        if preferCurrentRecordingSource {
            return currentCapturePurpose == .meeting
        }

        return meeting.supportsMeetingConversation
    }

    // MARK: - Notifications

    func notifySuccess(for transcription: Transcription) {
        let suffix =
            transcription.isPostProcessed
                ? "notification.transcription_processed".localized
                : "notification.transcription_transcribed".localized
        let body = "notification.transcription_body".localized(
            with: transcription.meeting.appName,
            transcription.wordCount,
            suffix
        )

        notificationService.sendNotification(
            title: "notification.transcription_completed".localized,
            body: body
        )

        NotificationCenter.default.post(
            name: .meetingAssistantTranscriptionSaved,
            object: nil,
            userInfo: [AppNotifications.UserInfoKey.transcriptionId: transcription.id.uuidString]
        )
    }

    func handleTranscriptionError(_ error: Error) {
        AppLogger.error("Transcription failed", category: .recordingManager, error: error)
        lastError = error

        transcriptionStatus.recordError(.transcriptionFailed(error.localizedDescription))
        transcriptionStatus.completeTranscription(success: false)

        notificationService.sendNotification(
            title: "notification.transcription_failed".localized,
            body: error.localizedDescription
        )
    }

    func scheduleStatusReset() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Constants.statusResetDelay))
            self.transcriptionStatus.resetToIdle()
        }
    }

    /// Get audio duration from file for progress estimation.
    func getAudioDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            AppLogger.error("Failed to load audio duration", category: .recordingManager, error: error)
            return nil
        }
    }
}
