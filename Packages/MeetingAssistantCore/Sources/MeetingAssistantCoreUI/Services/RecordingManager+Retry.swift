import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Retry Transcription

extension RecordingManager {
    /// Retry transcription for an existing entry using the currently active model.
    /// - Parameter transcription: Existing transcription to overwrite with new results.
    public func retryTranscription(for transcription: Transcription) async {
        guard !isTranscribing else {
            AppLogger.info("Already transcribing", category: .recordingManager)
            return
        }

        guard let audioURL = resolveRetryAudioURL(for: transcription) else { return }

        await runRetryTranscription(audioURL: audioURL, transcription: transcription)
    }

    func resolveRetryAudioURL(for transcription: Transcription) -> URL? {
        guard let audioURL = transcription.audioURL else {
            AppLogger.error("Audio file missing for retry", category: .recordingManager, extra: ["id": transcription.id.uuidString])
            lastError = AudioImportError.fileNotFound
            return nil
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            AppLogger.error("Audio file not found for retry", category: .recordingManager, extra: ["path": audioURL.path])
            lastError = AudioImportError.fileNotFound
            return nil
        }

        return audioURL
    }

    func runRetryTranscription(audioURL: URL, transcription: Transcription) async {
        isTranscribing = true
        let audioDuration = await getAudioDuration(from: audioURL)
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)

        do {
            let updated = try await performRetryTranscription(
                audioURL: audioURL,
                transcription: transcription,
                audioDuration: audioDuration
            )
            try await storage.saveTranscription(updated)
            transcriptionStatus.completeTranscription(success: true)
            notifySuccess(for: updated)
            scheduleStatusReset()
        } catch {
            handleTranscriptionError(error)
        }

        isTranscribing = false
    }

    func performRetryTranscription(
        audioURL: URL,
        transcription: Transcription,
        audioDuration: Double?
    ) async throws -> Transcription {
        try await performHealthCheck()

        let transcriptionStart = Date()
        let response = try await performTranscription(audioURL: audioURL)
        let transcriptionProcessingDuration = Date().timeIntervalSince(transcriptionStart)
        let settings = AppSettingsStore.shared
        let replacedText = applyVocabularyReplacements(
            to: response.text,
            with: settings.vocabularyReplacementRules
        )
        let replacedSegments = applyVocabularyReplacements(
            to: response.segments,
            with: settings.vocabularyReplacementRules
        )
        let qualityProfile = transcriptPreprocessor.preprocess(
            transcriptionText: replacedText,
            segments: replacedSegments.map {
                DomainTranscriptionSegment(
                    id: $0.id,
                    speaker: $0.speaker,
                    text: $0.text,
                    startTime: $0.startTime,
                    endTime: $0.endTime
                )
            },
            asrConfidenceScore: response.confidenceScore
        )
        let includeQualityMetadata = !isDictationMode(for: transcription.meeting)
        let postProcessingInput = mergedPostProcessingInput(
            transcriptionText: qualityProfile.normalizedTextForIntelligence,
            qualityProfile: qualityProfile,
            context: postProcessingContext,
            includeQualityMetadata: includeQualityMetadata
        )

        let meeting = updatedMeeting(for: transcription.meeting, audioDuration: audioDuration)
        let postProcessing = await applyPostProcessing(
            postProcessingInput: postProcessingInput,
            meeting: meeting,
            qualityProfile: qualityProfile
        )

        return Transcription(
            id: transcription.id,
            meeting: meeting,
            contextItems: transcription.contextItems,
            segments: replacedSegments,
            text: postProcessing.processedContent ?? replacedText,
            rawText: response.text,
            processedContent: postProcessing.processedContent,
            canonicalSummary: postProcessing.canonicalSummary,
            qualityProfile: qualityProfile,
            postProcessingPromptId: postProcessing.promptId,
            postProcessingPromptTitle: postProcessing.promptTitle,
            language: response.language,
            createdAt: transcription.createdAt,
            modelName: response.model,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcriptionProcessingDuration,
            postProcessingDuration: postProcessing.duration,
            postProcessingModel: postProcessing.model,
            meetingType: transcription.meeting.type.rawValue
        )
    }

    // MARK: - Vocabulary Replacements

    func applyVocabularyReplacements(
        to text: String,
        with rules: [VocabularyReplacementRule]
    ) -> String {
        var output = text

        for rule in rules {
            let find = rule.find.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !find.isEmpty else { continue }

            let escapedFind = NSRegularExpression.escapedPattern(for: find)
            let pattern = "\\b\(escapedFind)\\b"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let escapedReplacement = NSRegularExpression.escapedTemplate(for: rule.replace)
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: escapedReplacement
            )
        }

        return output
    }

    func applyVocabularyReplacements(
        to segments: [Transcription.Segment],
        with rules: [VocabularyReplacementRule]
    ) -> [Transcription.Segment] {
        segments.map { segment in
            Transcription.Segment(
                id: segment.id,
                speaker: segment.speaker,
                text: applyVocabularyReplacements(to: segment.text, with: rules),
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    // MARK: - Post Processing Input

    func mergedPostProcessingInput(
        transcriptionText: String,
        qualityProfile: TranscriptionQualityProfile,
        context: String?,
        includeQualityMetadata: Bool
    ) -> String {
        var blocks = [transcriptionText]
        if includeQualityMetadata {
            blocks.append(qualityMetadataBlock(from: qualityProfile))
        }

        if let context {
            let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContext.isEmpty {
                blocks.append(
                    """
                    <CONTEXT_METADATA>
                    \(trimmedContext)
                    </CONTEXT_METADATA>
                    """
                )
            }
        }

        return blocks.joined(separator: "\n\n")
    }

    func qualityMetadataBlock(from qualityProfile: TranscriptionQualityProfile) -> String {
        let markerLines: [String] = if qualityProfile.markers.isEmpty {
            ["none"]
        } else {
            qualityProfile.markers.map { marker in
                "- [\(marker.reason.rawValue)] \(marker.snippet) [\(marker.startTime)-\(marker.endTime)]"
            }
        }

        return """
        <TRANSCRIPT_QUALITY>
        normalizationVersion: \(qualityProfile.normalizationVersion)
        overallConfidence: \(qualityProfile.overallConfidence)
        containsUncertainty: \(qualityProfile.containsUncertainty)
        markers:
        \(markerLines.joined(separator: "\n"))
        </TRANSCRIPT_QUALITY>
        """
    }

    func recalibrateCanonicalSummary(
        _ summary: CanonicalSummary,
        with qualityProfile: TranscriptionQualityProfile
    ) -> CanonicalSummary {
        let trustFlags = CanonicalSummary.TrustFlags(
            isGroundedInTranscript: summary.trustFlags.isGroundedInTranscript,
            containsSpeculation: summary.trustFlags.containsSpeculation || qualityProfile.containsUncertainty,
            isHumanReviewed: summary.trustFlags.isHumanReviewed,
            confidenceScore: min(summary.trustFlags.confidenceScore, qualityProfile.overallConfidence)
        )

        return CanonicalSummary(
            schemaVersion: summary.schemaVersion,
            generatedAt: summary.generatedAt,
            summary: summary.summary,
            keyPoints: summary.keyPoints,
            decisions: summary.decisions,
            actionItems: summary.actionItems,
            openQuestions: summary.openQuestions,
            trustFlags: trustFlags
        )
    }

    func updatedMeeting(for meeting: Meeting, audioDuration: Double?) -> Meeting {
        guard let audioDuration else { return meeting }
        guard meeting.endTime == nil else { return meeting }

        var updatedMeeting = meeting
        updatedMeeting.endTime = meeting.startTime.addingTimeInterval(audioDuration)
        return updatedMeeting
    }

    func resolveInputSourceLabel(for meeting: Meeting) -> String? {
        if meeting.app == .importedFile {
            return "meeting.app.imported".localized
        }

        switch recordingSource {
        case .microphone:
            return resolveMicrophoneDeviceName() ?? "recording.source.microphone".localized
        case .system:
            return "recording.source.system".localized
        case .all:
            let system = "recording.source.system".localized
            let mic = resolveMicrophoneDeviceName()
            if let mic {
                return "\(system) + \(mic)"
            }
            let microphone = "recording.source.microphone".localized
            return "\(system) + \(microphone)"
        }
    }

    func resolveMicrophoneDeviceName() -> String? {
        let settings = AppSettingsStore.shared

        if settings.useSystemDefaultInput {
            return resolveSystemDefaultMicrophoneDeviceName()
        }

        for uid in settings.audioDevicePriority {
            guard let id = audioDeviceManager.getAudioDeviceID(for: uid) else { continue }
            if let name = audioDeviceManager.getDeviceName(for: id) {
                return name
            }
        }

        return resolveSystemDefaultMicrophoneDeviceName()
    }

    func resolveSystemDefaultMicrophoneDeviceName() -> String? {
        if let id = audioDeviceManager.getDefaultInputDeviceID(),
           let name = audioDeviceManager.getDeviceName(for: id)
        {
            return name
        }

        if let device = audioDeviceManager.availableInputDevices.first(where: { $0.isDefault }) {
            return device.name
        }

        return nil
    }
}
