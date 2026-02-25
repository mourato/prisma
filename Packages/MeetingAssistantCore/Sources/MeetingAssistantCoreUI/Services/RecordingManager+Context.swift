import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Context Capture

extension RecordingManager {
    func capturePostProcessingContext(for meeting: Meeting) async -> (context: String?, items: [TranscriptionContextItem]) {
        let settings = AppSettingsStore.shared
        let activeTabURL = activeBrowserURL(for: meeting.appBundleIdentifier)?.absoluteString

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
                includeWindowOCR: settings.contextAwarenessIncludeWindowOCR,
                includeAccessibilityText: settings.contextAwarenessIncludeAccessibilityText,
                protectSensitiveApps: settings.contextAwarenessProtectSensitiveApps,
                redactSensitiveData: settings.contextAwarenessRedactSensitiveData,
                excludedBundleIDs: settings.contextAwarenessExcludedBundleIDs
            )
        )

        var context = contextAwarenessService.makePostProcessingContext(from: snapshot)
        var items = makeContextItems(from: snapshot)

        if let activeTabURL {
            items.append(TranscriptionContextItem(source: .activeTabURL, text: activeTabURL))

            let activeTabURLBlock = "- Active tab URL: \(activeTabURL)"
            if let existingContext = context,
               !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                context = "\(existingContext)\n\(activeTabURLBlock)"
            } else {
                context = """
                CONTEXT_METADATA
                \(activeTabURLBlock)
                """
            }
        }

        if isDictationMode(for: meeting),
           settings.contextAwarenessIncludeAccessibilityText,
           snapshot.activeAccessibilityText == nil,
           let focusedText = await captureFocusedTextContext(settings: settings),
           !items.contains(where: { $0.source == .focusedText && $0.text == focusedText })
        {
            items.append(TranscriptionContextItem(source: .focusedText, text: focusedText))

            let focusedTextBlock = """
            - Focused text:
            \(focusedText)
            """

            if let existingContext = context,
               !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                context = "\(existingContext)\n\(focusedTextBlock)"
            } else {
                context = """
                CONTEXT_METADATA
                \(focusedTextBlock)
                """
            }
        }

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
        } else {
            AppLogger.debug(
                "Context capture finished",
                category: .recordingManager,
                extra: [
                    "reasonCode": "context.captured",
                    "itemCount": items.count,
                    "sources": items.map(\ .source.rawValue).joined(separator: ","),
                ]
            )
        }

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

    func capturePostProcessingContextWithTimeout(
        for meeting: Meeting
    ) async -> (context: String?, items: [TranscriptionContextItem], didTimeout: Bool) {
        await withTaskGroup(
            of: (context: String?, items: [TranscriptionContextItem], didTimeout: Bool).self,
            returning: (context: String?, items: [TranscriptionContextItem], didTimeout: Bool).self
        ) { group in
            group.addTask { [weak self] in
                guard let self else {
                    return (nil, [], false)
                }
                let capture = await capturePostProcessingContext(for: meeting)
                return (capture.context, capture.items, false)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: Constants.startContextCaptureTimeout)
                return (nil, [], true)
            }

            let firstResult = await group.next() ?? (nil, [], true)
            group.cancelAll()
            return firstResult
        }
    }

    func startContextCaptureAfterRecordingStart(meetingID: UUID, source: RecordingSource) {
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let contextCaptureStartAt = Date()

            let activeContext = try? await activeAppContextProvider.fetchActiveAppContext()
            guard !Task.isCancelled else { return }
            guard var meeting = currentMeeting, meeting.id == meetingID else { return }

            if source == .microphone {
                dictationStartBundleIdentifier = activeContext?.bundleIdentifier
                dictationStartURL = activeBrowserURL(for: activeContext?.bundleIdentifier)
            } else {
                dictationStartBundleIdentifier = nil
                dictationStartURL = nil
            }

            meeting = applyStartAppContext(meeting, source: source, activeContext: activeContext)
            currentMeeting = meeting

            let captureResult = await capturePostProcessingContextWithTimeout(for: meeting)
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
        }
    }
}
