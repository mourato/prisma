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
        setupContextMenu()
        globalShortcutController.start()
        assistantShortcutController.start()
        recordingCancelShortcutController.start()
        setupRecordingObservation()
        floatingIndicatorController.prewarm()
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        recordingCancelShortcutController.stop()
    }

    // MARK: - Onboarding

    func showFirstLaunchOnboarding() {
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
        setupContextMenu()
        globalShortcutController.start()
        assistantShortcutController.start()
        recordingCancelShortcutController.start()
        setupRecordingObservation()
        floatingIndicatorController.prewarm()
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
    }

    private func openSettingsOnLaunchIfEnabled() {
        guard settingsStore.showSettingsOnLaunch else { return }
        NavigationService.shared.openSettings()
    }

    private func configureNavigationService() {
        NavigationService.shared.registerOpenSettingsHandler { [weak self] in
            self?.settingsWindowController.showSettingsWindow()
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
        updateFloatingIndicator(
            isRecording: isRecording || isAssistantRecording,
            isAssistantRecording: isAssistantRecording,
            isStarting: isStarting,
            isProcessing: isProcessing,
            meetingType: currentMeetingType
        )

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
            let triggerLabel = source == .microphone ? "menu.dictation" : "menu.meeting"
            await recordingManager.startRecording(
                source: source,
                requestedAt: Date(),
                triggerLabel: triggerLabel
            )
        }
    }
}
