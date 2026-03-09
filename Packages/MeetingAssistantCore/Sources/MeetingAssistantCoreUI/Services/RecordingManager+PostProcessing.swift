import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Post Processing Configuration

extension RecordingManager {
    struct UseCaseConfig {
        let kernelMode: IntelligenceKernelMode
        let applyPostProcessing: Bool
        let dictationStructuredPostProcessingEnabled: Bool
        let postProcessingPrompt: DomainPostProcessingPrompt?
        let defaultPostProcessingPrompt: DomainPostProcessingPrompt?
        let postProcessingModel: String?
        let autoDetectMeetingType: Bool
        let availablePrompts: [DomainPostProcessingPrompt]
        let postProcessingContext: String?
        let postProcessingContextItems: [TranscriptionContextItem]
    }

    func makeUseCaseConfig(meeting: Meeting, settings: AppSettingsStore) -> UseCaseConfig {
        let kernelMode = postProcessingKernelMode(for: meeting)
        let isDictation = kernelMode == .dictation
        let readinessIssue = settings.postProcessingEnabled
            ? settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: apiKeyExists)
            : nil
        setPostProcessingReadinessWarning(issue: readinessIssue, mode: kernelMode)
        let applyPostProcessing = Self.shouldApplyEnhancementsPostProcessing(
            settings: settings,
            kernelMode: kernelMode,
            apiKeyExists: apiKeyExists
        )

        let disabledForRecording = isDictation
            ? settings.isDictationPostProcessingDisabled
            : settings.isMeetingPostProcessingDisabled
        let shouldApplyPostProcessing = applyPostProcessing && !disabledForRecording

        if settings.postProcessingEnabled, let readinessIssue {
            let reasonCode = readinessIssue.rawValue
            AppLogger.info(
                "Post-processing disabled for this recording: enhancements configuration not ready",
                category: .recordingManager,
                extra: ["reasonCode": reasonCode]
            )
        }

        guard shouldApplyPostProcessing else {
            let reasonCode = resolveDisabledReasonCode(
                settings: settings,
                readinessIssue: readinessIssue,
                disabledForRecording: disabledForRecording,
                isDictation: isDictation
            )

            AppLogger.info(
                "Post-processing skipped for this recording",
                category: .recordingManager,
                extra: [
                    "mode": kernelMode.rawValue,
                    "reasonCode": reasonCode,
                    "isDictation": isDictation,
                ]
            )
            return UseCaseConfig(
                kernelMode: kernelMode,
                applyPostProcessing: false,
                dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
                postProcessingPrompt: nil,
                defaultPostProcessingPrompt: nil,
                postProcessingModel: nil,
                autoDetectMeetingType: false,
                availablePrompts: [],
                postProcessingContext: nil,
                postProcessingContextItems: postProcessingContextItems
            )
        }

        let availablePrompts = makeAvailablePrompts(isDictation: isDictation, settings: settings)
        let defaultMeetingPrompt = makeDefaultMeetingPrompt(isDictation: isDictation, settings: settings)
        let prompt = resolvePostProcessingPromptForUseCase(
            meeting: meeting,
            isDictation: isDictation,
            settings: settings,
            defaultMeetingPrompt: defaultMeetingPrompt
        )

        let autoDetectMeetingType = !isDictation && meeting.type == .autodetect

        AppLogger.info(
            "Post-processing configured for this recording",
            category: .recordingManager,
            extra: [
                "mode": kernelMode.rawValue,
                "isDictation": isDictation,
                "promptTitle": prompt?.title ?? "nil",
                "autoDetectMeetingType": autoDetectMeetingType,
            ]
        )

        var resolvedContextItems = postProcessingContextItems
        if let meetingNotesItem = currentMeetingNotesContextItem() {
            if let existingIndex = resolvedContextItems.firstIndex(where: { $0.source == .meetingNotes }) {
                resolvedContextItems[existingIndex] = meetingNotesItem
            } else {
                resolvedContextItems.append(meetingNotesItem)
            }
        }

        return UseCaseConfig(
            kernelMode: kernelMode,
            applyPostProcessing: true,
            dictationStructuredPostProcessingEnabled: settings.dictationStructuredPostProcessingEnabled,
            postProcessingPrompt: prompt,
            defaultPostProcessingPrompt: autoDetectMeetingType ? defaultMeetingPrompt : nil,
            postProcessingModel: settings.resolvedEnhancementsAIConfiguration(for: kernelMode).selectedModel,
            autoDetectMeetingType: autoDetectMeetingType,
            availablePrompts: availablePrompts,
            postProcessingContext: postProcessingContext,
            postProcessingContextItems: resolvedContextItems
        )
    }

    private func resolveDisabledReasonCode(
        settings: AppSettingsStore,
        readinessIssue: EnhancementsInferenceReadinessIssue?,
        disabledForRecording: Bool,
        isDictation: Bool
    ) -> String {
        if !settings.postProcessingEnabled {
            "post_processing.disabled"
        } else if let readinessIssue {
            readinessIssue.rawValue
        } else if disabledForRecording {
            isDictation ? "dictation.prompt.disabled" : "meeting.prompt.disabled"
        } else {
            "post_processing.unknown"
        }
    }

    #if DEBUG
    func debugResolvePostProcessingConfiguration(
        meeting: Meeting,
        settings: AppSettingsStore = .shared
    ) -> PostProcessingConfigurationDebugInfo {
        let kernelMode = postProcessingKernelMode(for: meeting)
        let config = makeUseCaseConfig(meeting: meeting, settings: settings)
        return PostProcessingConfigurationDebugInfo(
            kernelMode: kernelMode,
            applyPostProcessing: config.applyPostProcessing,
            promptId: config.postProcessingPrompt?.id,
            promptTitle: config.postProcessingPrompt?.title
        )
    }
    #endif

    static func shouldApplyEnhancementsPostProcessing(
        settings: AppSettingsStore,
        kernelMode: IntelligenceKernelMode,
        apiKeyExists: ((AIProvider) -> Bool)? = nil
    ) -> Bool {
        let readinessIssue = settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: apiKeyExists)
        let kernelModeEnabled: Bool = switch kernelMode {
        case .dictation:
            true
        case .meeting, .assistant:
            settings.isIntelligenceKernelModeEnabled(kernelMode)
        }

        return settings.postProcessingEnabled
            && readinessIssue == nil
            && kernelModeEnabled
    }

    func refreshPostProcessingReadinessWarning(
        for kernelMode: IntelligenceKernelMode,
        settings: AppSettingsStore = .shared,
        apiKeyExists: ((AIProvider) -> Bool)? = nil
    ) {
        let resolvedAPIKeyExists = apiKeyExists ?? self.apiKeyExists
        let issue = settings.postProcessingEnabled
            ? settings.enhancementsInferenceReadinessIssue(for: kernelMode, apiKeyExists: resolvedAPIKeyExists)
            : nil
        setPostProcessingReadinessWarning(issue: issue, mode: kernelMode)
    }

    func clearPostProcessingReadinessWarning() {
        postProcessingReadinessWarningIssue = nil
        postProcessingReadinessWarningMode = nil
        activePostProcessingKernelMode = nil
    }

    func setPostProcessingReadinessWarning(
        issue: EnhancementsInferenceReadinessIssue?,
        mode: IntelligenceKernelMode
    ) {
        postProcessingReadinessWarningIssue = issue
        postProcessingReadinessWarningMode = issue == nil ? nil : mode
    }

    // MARK: - Prompt Resolution

    func makeAvailablePrompts(isDictation: Bool, settings: AppSettingsStore) -> [DomainPostProcessingPrompt] {
        guard !isDictation else { return [] }

        let builtIn: [PostProcessingPrompt] = [.standup, .presentation, .designReview, .oneOnOne, .planning]
        return (builtIn + settings.meetingPrompts).map(domainPrompt(from:))
    }

    func makeDefaultMeetingPrompt(
        isDictation: Bool,
        settings: AppSettingsStore
    ) -> DomainPostProcessingPrompt? {
        guard !isDictation else { return nil }

        if let selected = settings.selectedPrompt {
            return domainPrompt(from: selected)
        }

        return domainPrompt(from: PromptService.shared.strategy(for: .general).promptObject())
    }

    func resolvePostProcessingPromptForUseCase(
        meeting: Meeting,
        isDictation: Bool,
        settings: AppSettingsStore,
        defaultMeetingPrompt: DomainPostProcessingPrompt?
    ) -> DomainPostProcessingPrompt? {
        if isDictation {
            let basePrompt = settings.selectedDictationPrompt ?? .cleanTranscription
            let resolvedPrompt = promptWithDictationRuleOverrides(prompt: basePrompt, settings: settings)
            return domainPrompt(from: resolvedPrompt)
        }

        switch meeting.type {
        case .autodetect:
            return nil
        case .standup:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .standup))
        case .presentation:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .presentation))
        case .designReview:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .designReview))
        case .oneOnOne:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .oneOnOne))
        case .planning:
            return domainPrompt(from: promptWithMeetingSummaryOverrides(prompt: .planning))
        case .general:
            guard let defaultMeetingPrompt else { return nil }
            let prompt = PostProcessingPrompt(
                id: defaultMeetingPrompt.id,
                title: defaultMeetingPrompt.title,
                promptText: defaultMeetingPrompt.content,
                isPredefined: false
            )
            let enrichedPrompt = promptWithMeetingSummaryOverrides(prompt: prompt)
            return domainPrompt(from: enrichedPrompt)
        }
    }

    func domainPrompt(from prompt: PostProcessingPrompt) -> DomainPostProcessingPrompt {
        DomainPostProcessingPrompt(id: prompt.id, title: prompt.title, content: prompt.promptText, isDefault: false)
    }

    // MARK: - Dictation Prompt Overrides

    func promptWithDictationRuleOverrides(
        prompt: PostProcessingPrompt,
        settings: AppSettingsStore
    ) -> PostProcessingPrompt {
        var appliedInstructions: [String] = []

        if shouldForceMarkdownForDictation(settings: settings) {
            appliedInstructions.append(Self.markdownFormatInstruction)
        }

        let outputLanguage = outputLanguageForDictation(settings: settings)
        if outputLanguage != .original {
            appliedInstructions.append(Self.translationInstruction(for: outputLanguage))
        }

        if let customInstructions = effectiveCustomPromptInstructionsForDictation(settings: settings) {
            appliedInstructions.append(Self.siteOrAppPriorityInstructionBlock(customInstructions))
        }

        guard !appliedInstructions.isEmpty else { return prompt }

        let augmentedText = ([prompt.promptText] + appliedInstructions).joined(separator: "\n\n")

        return PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: augmentedText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: prompt.isPredefined
        )
    }

    func effectiveCustomPromptInstructionsForDictation(settings: AppSettingsStore) -> String? {
        if let websiteTarget = matchingWebContextTargetForDictation(settings: settings),
           let instructions = websiteTarget.customPromptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instructions.isEmpty
        {
            return instructions
        }

        if let appRule = matchingDictationAppRule(settings: settings),
           let instructions = appRule.customPromptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instructions.isEmpty
        {
            return instructions
        }

        return nil
    }

    func matchingDictationAppRule(settings: AppSettingsStore) -> DictationAppRule? {
        guard let bundleIdentifier = dictationStartBundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        return settings.dictationAppRules.first {
            WebTargetDetection.normalizeBundleIdentifier($0.bundleIdentifier) == normalized
        }
    }

    func outputLanguageForDictation(settings: AppSettingsStore) -> DictationOutputLanguage {
        if let override = dictationSessionOutputLanguageOverride {
            return override
        }

        if let websiteTarget = matchingWebContextTargetForDictation(settings: settings),
           websiteTarget.outputLanguage != .original
        {
            return websiteTarget.outputLanguage
        }

        guard let rule = matchingDictationAppRule(settings: settings) else { return .original }
        return rule.outputLanguage
    }

    func shouldForceMarkdownForDictation(settings: AppSettingsStore) -> Bool {
        guard let bundleIdentifier = dictationStartBundleIdentifier else { return false }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        if let websiteTarget = matchingWebContextTargetForDictation(settings: settings) {
            return websiteTarget.forceMarkdownOutput
        }

        if let rule = matchingDictationAppRule(settings: settings), rule.forceMarkdownOutput {
            return true
        }

        let appTargets = Set(settings.markdownTargetBundleIdentifiers.map(WebTargetDetection.normalizeBundleIdentifier))
        if appTargets.contains(normalized) {
            return true
        }

        return false
    }

    func matchingWebContextTargetForDictation(settings: AppSettingsStore) -> WebContextTarget? {
        guard let bundleIdentifier = dictationStartBundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)
        let webTargets = settings.markdownWebTargets
        guard !webTargets.isEmpty else { return nil }

        if let url = dictationStartURL,
           let target = WebTargetDetection.matchTarget(
               for: url,
               bundleIdentifier: normalized,
               targets: webTargets,
               fallbackBrowserBundleIdentifiers: settings.effectiveWebTargetBrowserBundleIdentifiers
           )
        {
            return target
        }

        return WebTargetDetection.matchTargetByWindowTitle(
            bundleIdentifier: normalized,
            targets: webTargets,
            fallbackBrowserBundleIdentifiers: settings.effectiveWebTargetBrowserBundleIdentifiers
        )
    }

    func activeBrowserURL(for bundleIdentifier: String?) -> URL? {
        guard let bundleIdentifier else { return nil }
        let normalized = WebTargetDetection.normalizeBundleIdentifier(bundleIdentifier)

        if let provider = browserProviders[normalized] {
            return provider.activeTabURL()
        }

        guard let provider = BrowserProviderRegistry.provider(for: bundleIdentifier) else {
            return nil
        }

        browserProviders[normalized] = provider
        return provider.activeTabURL()
    }

    static let markdownFormatInstruction = """
    <OUTPUT_FORMAT>
    ALWAYS format the output as Markdown. When formatting using Markdown, use traditional formatting conventions for ordered or unordered lists, **bold**, *italics*, and headings as well.
    </OUTPUT_FORMAT>
    """

    static func translationInstruction(for language: DictationOutputLanguage) -> String {
        """
        <OUTPUT_LANGUAGE>
        Translate the final output to \(language.instructionDisplayName). This requirement overrides any instruction that says to keep the original language.
        </OUTPUT_LANGUAGE>
        """
    }

    static let meetingNotesPriorityInstruction = """
    <MEETING_NOTES_POLICY>
    If a <MEETING_NOTES> block is present, treat it as high-priority user-provided signal.
    Preserve those points in the summary and enrich them only with grounded details from the transcription.
    Never contradict explicit meeting notes unless the transcription clearly disproves them.
    </MEETING_NOTES_POLICY>
    """

    func promptWithMeetingSummaryOverrides(
        prompt: PostProcessingPrompt
    ) -> PostProcessingPrompt {
        let augmentedText = [
            prompt.promptText,
            Self.meetingNotesPriorityInstruction,
        ].joined(separator: "\n\n")

        return PostProcessingPrompt(
            id: prompt.id,
            title: prompt.title,
            promptText: augmentedText,
            isActive: prompt.isActive,
            icon: prompt.icon,
            description: prompt.description,
            isPredefined: prompt.isPredefined
        )
    }

    static func siteOrAppPriorityInstructionBlock(_ instructions: String) -> String {
        """
        <\(AIPromptTemplates.siteOrAppPriorityTag)>
        \(instructions)
        </\(AIPromptTemplates.siteOrAppPriorityTag)>
        """
    }

    // MARK: - Mode Detection

    func isDictationMode(for meeting: Meeting?) -> Bool {
        if let meeting, meeting.app == .importedFile {
            return false
        }

        if isRecording || isTranscribing {
            return currentCapturePurpose == .dictation
        }

        return meeting?.capturePurpose == .dictation || currentCapturePurpose == .dictation
    }

    func postProcessingKernelMode(for meeting: Meeting?) -> IntelligenceKernelMode {
        if let activePostProcessingKernelMode {
            return activePostProcessingKernelMode
        }

        return isDictationMode(for: meeting) ? .dictation : .meeting
    }

    func isPostProcessingDisabled(isDictation: Bool, settings: AppSettingsStore) -> Bool {
        if isDictation { return settings.isDictationPostProcessingDisabled }
        return settings.isMeetingPostProcessingDisabled
    }
}
