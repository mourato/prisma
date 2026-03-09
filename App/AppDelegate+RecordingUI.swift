import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore
import os
import SwiftUI

extension AppDelegate {
    // MARK: - Public Methods

    /// Update menu bar icon and menu item based on recording state.
    func updateStatusIcon(isRecording: Bool) {
        let accessibilityKey = isRecording ? "menubar.accessibility.recording" : "menubar.accessibility.idle"
        let accessibilityDesc = accessibilityKey.localized
        statusItem?.button?.image = makeStatusBarImage(
            isRecording: isRecording,
            accessibilityDescription: accessibilityDesc
        )
        statusItem?.button?.contentTintColor = nil
    }

    func makeStatusBarImage(isRecording: Bool, accessibilityDescription: String) -> NSImage? {
        let iconName = isRecording ? "record.circle.fill" : "waveform"
        guard let baseImage = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: accessibilityDescription
        ) else {
            return nil
        }

        guard isRecording else {
            baseImage.isTemplate = true
            return baseImage
        }

        let redConfig = NSImage.SymbolConfiguration(hierarchicalColor: .systemRed)
        let configuredImage = baseImage.withSymbolConfiguration(redConfig) ?? baseImage
        configuredImage.isTemplate = false
        return configuredImage
    }

    func updateFloatingIndicator(
        isRecording: Bool,
        isAssistantRecording: Bool,
        isStarting: Bool,
        isProcessing: Bool,
        recordingSource: RecordingSource,
        meetingType: MeetingType? = nil
    ) {
        let recordingState = indicatorRenderState(
            mode: .recording,
            recordingSource: recordingSource,
            meetingType: meetingType,
            isAssistantRecording: isAssistantRecording
        )
        let startingState = indicatorRenderState(
            mode: .starting,
            recordingSource: recordingSource,
            meetingType: meetingType,
            isAssistantRecording: isAssistantRecording
        )
        let processingState = indicatorRenderState(
            mode: .processing,
            recordingSource: recordingSource,
            meetingType: meetingType,
            isAssistantRecording: isAssistantRecording
        )

        if isRecording {
            if isAssistantRecording {
                floatingIndicatorController.show(
                    renderState: recordingState,
                    onStop: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.assistantVoiceCommandService.stopAndProcess()
                        }
                    },
                    onCancel: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.assistantVoiceCommandService.cancelRecording()
                        }
                    }
                )
            } else {
                floatingIndicatorController.show(renderState: recordingState)
            }
        } else if isStarting {
            floatingIndicatorController.show(renderState: startingState)
        } else if isProcessing {
            floatingIndicatorController.show(renderState: processingState)
        } else {
            floatingIndicatorController.hide()
        }
    }

    private func indicatorRenderState(
        mode: FloatingRecordingIndicatorMode,
        recordingSource: RecordingSource,
        meetingType: MeetingType?,
        isAssistantRecording: Bool
    ) -> RecordingIndicatorRenderState {
        guard isAssistantRecording else {
            return RecordingIndicatorRenderState.forRecordingSource(
                mode: mode,
                recordingSource: recordingSource,
                meetingType: meetingType
            )
        }

        switch floatingIndicatorController.renderState.kind {
        case .assistantIntegration:
            return RecordingIndicatorRenderState(
                mode: mode,
                kind: .assistantIntegration,
                assistantIntegrationID: floatingIndicatorController.renderState.assistantIntegrationID
            )
        case .assistant, .dictation, .meeting:
            return RecordingIndicatorRenderState(mode: mode, kind: .assistant)
        }
    }

    /// Applies the dock visibility setting by changing the app's activation policy.
    /// - Parameter showInDock: If true, shows the app in Dock and Cmd+Tab switcher.
    func applyDockVisibility(_ showInDock: Bool) {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        logger.info("Activation policy set to: \(showInDock ? "regular (dock)" : "accessory (menu bar only)")")
    }
}
