import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore
import os
import SwiftUI

extension AppDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Monitoring Services
        CrashReporter.shared.setup()
        PerformanceMonitor.shared.startMonitoring()
        configureNavigationService()

        // Show onboarding if first launch
        if !settingsStore.hasCompletedOnboarding {
            showFirstLaunchOnboarding()
            return // Defer rest of setup until onboarding completes
        }

        setupMenuBar()
        verifyPrimaryInterfaceAfterLaunch()
        setupContextMenu()
        globalShortcutController.start()
        assistantShortcutController.start()
        recordingCancelShortcutController.start()
        setupRecordingObservation()
        prewarmFloatingIndicatorIfEligible()
        updateMenuTitles() // Initial update

        // Warmup transcription model
        Task { @MainActor in
            do {
                try await TranscriptionClient.shared.warmupModel()
            } catch {
                self.logger.error("Failed to warmup model: \(error.localizedDescription)")
            }
        }

        // Run auto-cleanup logic
        Task {
            await performCleanup()
        }

        // Set initial activation policy based on user settings
        applyDockVisibility(settingsStore.showInDock)

        // Observe changes to dock visibility setting
        dockObserver = settingsStore.$showInDock
            .dropFirst() // Skip initial value (already applied above)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showInDock in
                self?.applyDockVisibility(showInDock)
            }

        openSettingsOnLaunchIfEnabled()
        scheduleLaunchVisibilityRecovery()
    }

    func applicationWillTerminate(_ notification: Notification) {
        recordingCancelShortcutController.stop()
    }

    // MARK: - Onboarding

    func showFirstLaunchOnboarding() {
        promoteAppForWindowPresentation()
        presentOnboarding { [weak self] in
            self?.completeOnboarding()
        }
    }

    func presentOnboarding(completion: @escaping () -> Void) {
        let permissionViewModel = PermissionViewModel(
            manager: recordingManager.permissionStatus,
            requestMicrophone: { [weak self] in
                await self?.recordingManager.requestPermission(for: .microphone)
            },
            requestScreen: { [weak self] in
                await self?.recordingManager.requestPermission(for: .all)
            },
            openMicrophoneSettings: { [weak self] in
                self?.recordingManager.openMicrophoneSettings()
            },
            openScreenSettings: { [weak self] in
                self?.recordingManager.openPermissionSettings()
            },
            requestAccessibility: { [weak self] in
                self?.recordingManager.requestAccessibilityPermission()
            },
            openAccessibilitySettings: { [weak self] in
                self?.recordingManager.openAccessibilitySettings()
            }
        )

        let shortcutViewModel = ShortcutSettingsViewModel()
        let assistantShortcutViewModel = AssistantShortcutSettingsViewModel()
        let onboardingViewModel = OnboardingViewModel()
        let modelManager = FluidAIModelManager.shared

        onboardingController.showOnboarding(
            viewModel: onboardingViewModel,
            permissionViewModel: permissionViewModel,
            shortcutViewModel: shortcutViewModel,
            assistantShortcutViewModel: assistantShortcutViewModel,
            modelManager: modelManager,
            refreshPermissions: { [weak self] in
                await self?.recordingManager.checkPermission()
            },
            completion: completion
        )
    }

    private func completeOnboarding() {
        settingsStore.hasCompletedOnboarding = true
        continueAppSetup()
    }

    private func continueAppSetup() {
        configureNavigationService()
        setupMenuBar()
        verifyPrimaryInterfaceAfterLaunch()
        setupContextMenu()
        globalShortcutController.start()
        assistantShortcutController.start()
        recordingCancelShortcutController.start()
        setupRecordingObservation()
        prewarmFloatingIndicatorIfEligible()
        updateMenuTitles()

        // Warmup transcription model
        Task { @MainActor in
            do {
                try await TranscriptionClient.shared.warmupModel()
            } catch {
                self.logger.error("Failed to warmup model: \(error.localizedDescription)")
            }
        }

        // Run auto-cleanup logic
        Task {
            await performCleanup()
        }

        // Set initial activation policy based on user settings
        applyDockVisibility(settingsStore.showInDock)

        // Observe changes to dock visibility setting
        dockObserver = settingsStore.$showInDock
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showInDock in
                self?.applyDockVisibility(showInDock)
            }

        openSettingsOnLaunchIfEnabled()
        scheduleLaunchVisibilityRecovery()
    }

    private func openSettingsOnLaunchIfEnabled() {
        guard settingsStore.showSettingsOnLaunch else { return }
        promoteAppForWindowPresentation()
        settingsWindowController.showSettingsWindow()
    }

    /// Keeps indicator prewarming out of the launch critical path.
    /// Classic style has a known NSPanel constraint-loop instability on some systems.
    private func prewarmFloatingIndicatorIfEligible() {
        guard settingsStore.recordingIndicatorEnabled else { return }
        guard settingsStore.recordingIndicatorStyle == .mini else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.floatingIndicatorController.prewarm()
        }
    }

    private func promoteAppForWindowPresentation() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func verifyPrimaryInterfaceAfterLaunch() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let hasStatusButton = statusItem?.button != nil
            let isStatusItemVisible = statusItem?.isVisible ?? false
            guard hasStatusButton, isStatusItemVisible else {
                logger.fault("Primary UI did not initialize correctly. Presenting settings recovery window.")
                promoteAppForWindowPresentation()
                settingsWindowController.showSettingsWindow()
                return
            }
        }
    }

    private func configureNavigationService() {
        NavigationService.shared.registerOpenSettingsHandler { [weak self] in
            self?.settingsWindowController.showSettingsWindow()
        }
    }

    /// Ensures the app is recoverable when launch completes without any visible affordance.
    /// This protects against silent launch states where neither status item nor windows are visible.
    private func scheduleLaunchVisibilityRecovery() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }

            let hasStatusButton = statusItem?.button != nil
            let isStatusItemVisible = statusItem?.isVisible ?? false
            let hasVisibleWindow = NSApp.windows.contains(where: \.isVisible)

            guard !hasVisibleWindow else { return }
            guard !hasStatusButton || !isStatusItemVisible else { return }

            logger.fault("Launch recovery triggered: no visible status item and no visible window.")
            promoteAppForWindowPresentation()
            settingsWindowController.showSettingsWindow()
        }
    }

    // MARK: - Document Handling (Disabled for Menu Bar App)

    /// Prevent the app from reopening windows when activated.
    /// This is critical for menu bar-only apps in SPM builds.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Do not create new windows when app is reactivated
        false
    }

    /// Prevent the app from opening untitled files on launch.
    /// Without this, AppKit calls this method and crashes in SPM builds.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Menu bar apps don't open documents
        true
    }

    /// Prevent app from prompting to open a new document.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupRecordingObservation() {
        Publishers.MergeMany(
            recordingManager.isRecordingPublisher.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.isStartingPublisher.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.isTranscribingPublisher.map { _ in () }.eraseToAnyPublisher(),
            assistantVoiceCommandService.$isRecording.map { _ in () }.eraseToAnyPublisher(),
            assistantVoiceCommandService.$isProcessing.map { _ in () }.eraseToAnyPublisher(),
            recordingManager.currentMeetingPublisher.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$cancelRecordingShortcutDefinition.map { _ in () }.eraseToAnyPublisher()
        )
        // @Published emits in willSet; schedule refresh so re-reads observe committed values.
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.refreshRecordingUIState()
        }
        .store(in: &cancellables)

        refreshRecordingUIState()
    }

    private func refreshRecordingUIState() {
        let isRecording = recordingManager.isRecording
        let isStarting = recordingManager.isStartingRecording
        let isTranscribing = recordingManager.isTranscribing
        let isAssistantRecording = assistantVoiceCommandService.isRecording
        let isAssistantProcessing = assistantVoiceCommandService.isProcessing
        let isProcessing = isTranscribing || isAssistantProcessing
        let currentMeetingType = recordingManager.currentMeeting?.type
        let isAssistantOwnedOverlayVisible = floatingIndicatorController.isVisible && {
            switch floatingIndicatorController.renderState.kind {
            case .assistant, .assistantIntegration:
                true
            case .dictation, .meeting:
                false
            }
        }()
        let shouldDeferIndicatorUpdatesToAssistant = !isRecording
            && !isStarting
            && !isTranscribing
            && (isAssistantRecording || isAssistantProcessing || isAssistantOwnedOverlayVisible)
        let renderState = RecordingUIRenderState(
            isRecording: isRecording,
            isStarting: isStarting,
            isTranscribing: isTranscribing,
            isAssistantRecording: isAssistantRecording,
            isAssistantProcessing: isAssistantProcessing,
            meetingTypeRawValue: currentMeetingType?.rawValue
        )

        guard renderState != lastRecordingUIRenderState else {
            recordingCancelShortcutController.refresh()
            return
        }
        lastRecordingUIRenderState = renderState

        updateStatusIcon(isRecording: isRecording || isAssistantRecording || isStarting)
        if !shouldDeferIndicatorUpdatesToAssistant {
            updateFloatingIndicator(
                isRecording: isRecording,
                isAssistantRecording: false,
                isStarting: isStarting,
                isProcessing: isProcessing,
                capturePurpose: recordingManager.currentCapturePurpose,
                recordingSource: recordingManager.recordingSource,
                meetingType: currentMeetingType
            )
        }

        if isRecording || isStarting,
           settingsStore.recordingIndicatorEnabled,
           settingsStore.recordingIndicatorStyle != .none
        {
            recordingManager.noteIndicatorShownForStartIfNeeded()
        }

        updateMenuTitles()
        recordingCancelShortcutController.refresh()
    }

    func recordingCancelShortcutStateSnapshot() -> RecordingCancelShortcutState {
        RecordingCancelShortcutState(
            isRecordingManagerCaptureActive: recordingManager.isRecording || recordingManager.isStartingRecording,
            isAssistantCaptureActive: assistantVoiceCommandService.isRecording
        )
    }

    /// Toggle recording state when global shortcut is activated.
    func startRecording(source: RecordingSource) async {
        if recordingManager.isRecording {
            await recordingManager.stopRecording(transcribe: true)
        } else {
            let purpose: CapturePurpose = source == .microphone ? .dictation : .meeting
            let triggerLabel = purpose == .dictation ? "menu.dictation" : "menu.meeting"
            await recordingManager.startCapture(
                purpose: purpose,
                requestedAt: Date(),
                triggerLabel: triggerLabel
            )
        }
    }
}
