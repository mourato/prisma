import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Context Capture

private struct ContextCaptureResult {
    let context: String?
    let items: [TranscriptionContextItem]
    let didTimeout: Bool
}

extension RecordingManager {
    func capturePostProcessingContext(
        for meeting: Meeting,
        includeWindowOCR: Bool? = nil
    ) async -> (context: String?, items: [TranscriptionContextItem]) {
        let settings = AppSettingsStore.shared
        let activeTabURL = activeBrowserURL(for: meeting.appBundleIdentifier)?.absoluteString
        let shouldIncludeWindowOCR = includeWindowOCR ?? settings.contextAwarenessIncludeWindowOCR

        guard settings.contextAwarenessEnabled else {
            AppLogger.debug(
                "Context awareness disabled, skipping context capture",
                category: .recordingManager,
                extra: ["reasonCode": "context.disabled"]
            )

            guard let activeTabURL else {
                return (nil, [])
            }

            return (
                nil,
                [TranscriptionContextItem(source: .activeTabURL, text: activeTabURL)]
            )
        }

        let snapshot = await contextAwarenessService.captureSnapshot(
            options: .init(
                includeActiveApp: true,
                includeClipboard: settings.contextAwarenessIncludeClipboard,
                includeWindowOCR: shouldIncludeWindowOCR,
                includeAccessibilityText: settings.contextAwarenessIncludeAccessibilityText,
                protectSensitiveApps: settings.contextAwarenessProtectSensitiveApps,
                redactSensitiveData: settings.contextAwarenessRedactSensitiveData,
                excludedBundleIDs: settings.contextAwarenessExcludedBundleIDs
            )
        )

        var context = contextAwarenessService.makePostProcessingContext(from: snapshot)
        var items = makeContextItems(from: snapshot)

        if let activeTabURL {
            appendActiveTabURLContext(activeTabURL, to: &context, items: &items)
        }

        appendCalendarContextIfNeeded(for: meeting, to: &context, items: &items)
        await appendFocusedTextContextIfNeeded(
            snapshot: snapshot,
            meeting: meeting,
            settings: settings,
            context: &context,
            items: &items
        )

        logContextCaptureSummary(snapshot: snapshot, items: items, settings: settings)

        return (context, items)
    }

    func captureFocusedTextContext(settings: AppSettingsStore) async -> String? {
        guard settings.contextAwarenessIncludeAccessibilityText else { return nil }

        guard AccessibilityPermissionService.isTrusted() else {
            AppLogger.warning(
                "Focused text capture skipped: accessibility permission not granted",
                category: .recordingManager,
                extra: ["reasonCode": "focused_text.permission_denied"]
            )
            AccessibilityPermissionService.requestPermission()
            return nil
        }

        do {
            let snapshot = try await textContextProvider.fetchTextContext()
            let guarded = textContextGuardrails.apply(to: snapshot.text, policy: textContextPolicy)
            var normalized = guarded.trimmingCharacters(in: .whitespacesAndNewlines)

            if settings.contextAwarenessRedactSensitiveData {
                normalized = ContextAwarenessPrivacy.redactSensitiveText(normalized) ?? ""
            }

            return normalized.isEmpty ? nil : normalized
        } catch {
            AppLogger.warning(
                "Focused text capture failed",
                category: .recordingManager,
                extra: [
                    "reasonCode": "focused_text.provider_failed",
                    "error": error.localizedDescription,
                ]
            )
            return nil
        }
    }

    func makeContextItems(from snapshot: ContextAwarenessSnapshot) -> [TranscriptionContextItem] {
        var items: [TranscriptionContextItem] = []

        if let activeAppName = snapshot.activeAppName {
            items.append(TranscriptionContextItem(source: .activeApp, text: activeAppName))
        }

        if let activeWindowTitle = snapshot.activeWindowTitle {
            items.append(TranscriptionContextItem(source: .windowTitle, text: activeWindowTitle))
        }

        if let accessibilityText = snapshot.activeAccessibilityText {
            items.append(TranscriptionContextItem(source: .accessibilityText, text: accessibilityText))
        }

        if let clipboardText = snapshot.clipboardText {
            items.append(TranscriptionContextItem(source: .clipboard, text: clipboardText))
        }

        if let ocrText = snapshot.activeWindowOCRText {
            items.append(TranscriptionContextItem(source: .windowOCR, text: ocrText))
        }

        return items
    }

    private func capturePostProcessingContextWithTimeout(
        for meeting: Meeting,
        includeWindowOCR: Bool? = nil
    ) async -> ContextCaptureResult {
        await withTaskGroup(
            of: ContextCaptureResult.self,
            returning: ContextCaptureResult.self
        ) { group in
            group.addTask { [weak self] in
                guard let self else {
                    return ContextCaptureResult(context: nil, items: [], didTimeout: false)
                }
                let capture = await capturePostProcessingContext(
                    for: meeting,
                    includeWindowOCR: includeWindowOCR
                )
                return ContextCaptureResult(context: capture.context, items: capture.items, didTimeout: false)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: Constants.startContextCaptureTimeout)
                return ContextCaptureResult(context: nil, items: [], didTimeout: true)
            }

            let firstResult = await group.next() ?? ContextCaptureResult(context: nil, items: [], didTimeout: true)
            group.cancelAll()
            return firstResult
        }
    }

    func cancelPostStartCaptureTasks() {
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil
        deferredContextOCRTask?.cancel()
        deferredContextOCRTask = nil
    }

    func startContextCaptureAfterRecordingStart(meetingID: UUID) {
        cancelPostStartCaptureTasks()
        postStartContextCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let contextCaptureStartAt = Date()
            guard !Task.isCancelled else { return }
            guard let meeting = currentMeeting, meeting.id == meetingID else { return }

            let captureResult = await capturePostProcessingContextWithTimeout(
                for: meeting,
                includeWindowOCR: false
            )
            guard !Task.isCancelled else { return }
            guard currentMeeting?.id == meetingID else { return }

            postProcessingContext = captureResult.context
            postProcessingContextItems = captureResult.items

            if captureResult.didTimeout {
                AppLogger.warning(
                    "Context capture timed out after recording start",
                    category: .recordingManager
                )
            }

            PerformanceMonitor.shared.reportMetric(
                name: "recording_start_context_capture_ms",
                value: Date().timeIntervalSince(contextCaptureStartAt) * 1_000,
                unit: "ms"
            )

            scheduleDeferredWindowOCRCaptureIfNeeded(meetingID: meetingID)
        }
    }

    private func scheduleDeferredWindowOCRCaptureIfNeeded(meetingID: UUID) {
        deferredContextOCRTask?.cancel()

        let settings = AppSettingsStore.shared
        guard settings.contextAwarenessEnabled, settings.contextAwarenessIncludeWindowOCR else {
            deferredContextOCRTask = nil
            return
        }

        deferredContextOCRTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Constants.deferredWindowOCRCaptureDelay)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard isRecording, let meeting = currentMeeting, meeting.id == meetingID else { return }

            let captureResult = await capturePostProcessingContextWithTimeout(
                for: meeting,
                includeWindowOCR: true
            )

            guard !Task.isCancelled else { return }
            guard isRecording, currentMeeting?.id == meetingID else { return }
            guard let ocrItem = captureResult.items.first(where: { $0.source == .windowOCR }) else { return }

            var updatedItems = postProcessingContextItems
            let alreadyPresent = updatedItems.contains {
                $0.source == .windowOCR && $0.text == ocrItem.text
            }

            guard !alreadyPresent else { return }

            updatedItems.append(ocrItem)
            postProcessingContextItems = updatedItems

            var updatedContext = postProcessingContext
            appendContextBlock(
                """
                - Active window visible text (OCR):
                \(ocrItem.text)
                """,
                to: &updatedContext
            )
            postProcessingContext = updatedContext

            AppLogger.debug(
                "Deferred OCR context capture appended",
                category: .recordingManager,
                extra: ["meetingID": meetingID.uuidString]
            )
        }
    }

    private func appendContextBlock(_ block: String, to context: inout String?) {
        if let existingContext = context,
           !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            context = "\(existingContext)\n\(block)"
        } else {
            context = """
            CONTEXT_METADATA
            \(block)
            """
        }
    }

    private func appendActiveTabURLContext(
        _ activeTabURL: String,
        to context: inout String?,
        items: inout [TranscriptionContextItem]
    ) {
        items.append(TranscriptionContextItem(source: .activeTabURL, text: activeTabURL))
        appendContextBlock("- Active tab URL: \(activeTabURL)", to: &context)
    }

    private func appendCalendarContextIfNeeded(
        for meeting: Meeting,
        to context: inout String?,
        items: inout [TranscriptionContextItem]
    ) {
        guard meeting.supportsMeetingConversation, let calendarEvent = meeting.linkedCalendarEvent else { return }

        let calendarContext = calendarContextBlock(for: calendarEvent)
        items.append(TranscriptionContextItem(source: .calendarEvent, text: calendarContext))

        if let existingContext = context,
           !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            context = "\(existingContext)\n\(calendarContext)"
        } else {
            context = calendarContext
        }
    }

    private func appendFocusedTextContextIfNeeded(
        snapshot: ContextAwarenessSnapshot,
        meeting: Meeting,
        settings: AppSettingsStore,
        context: inout String?,
        items: inout [TranscriptionContextItem]
    ) async {
        guard isDictationMode(for: meeting) else { return }
        guard settings.contextAwarenessIncludeAccessibilityText else { return }
        guard snapshot.activeAccessibilityText == nil else { return }
        guard let focusedText = await captureFocusedTextContext(settings: settings) else { return }
        guard !items.contains(where: { $0.source == .focusedText && $0.text == focusedText }) else { return }

        items.append(TranscriptionContextItem(source: .focusedText, text: focusedText))
        appendContextBlock(
            """
            - Focused text:
            \(focusedText)
            """,
            to: &context
        )
    }

    private func logContextCaptureSummary(
        snapshot: ContextAwarenessSnapshot,
        items: [TranscriptionContextItem],
        settings: AppSettingsStore
    ) {
        if settings.contextAwarenessIncludeWindowOCR, snapshot.activeWindowOCRText == nil {
            AppLogger.debug(
                "Context capture finished without OCR text",
                category: .recordingManager,
                extra: ["reasonCode": "context.ocr_missing"]
            )
        }

        if items.isEmpty {
            AppLogger.info(
                "Context capture finished with no context items",
                category: .recordingManager,
                extra: ["reasonCode": "context.empty"]
            )
            return
        }

        AppLogger.debug(
            "Context capture finished",
            category: .recordingManager,
            extra: [
                "reasonCode": "context.captured",
                "itemCount": items.count,
                "sources": items.map(\.source.rawValue).joined(separator: ","),
            ]
        )
    }
}
