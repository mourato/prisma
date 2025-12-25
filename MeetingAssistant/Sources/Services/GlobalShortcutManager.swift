import Foundation
import Carbon.HIToolbox
import AppKit
import Combine
import os.log

/// Manages global keyboard shortcuts for the application.
/// Registers and handles system-wide hotkeys using Carbon Event Manager.
@MainActor
class GlobalShortcutManager: ObservableObject {
    static let shared = GlobalShortcutManager()
    
    private let logger = Logger(subsystem: "MeetingAssistant", category: "GlobalShortcutManager")
    
    // MARK: - Published State
    
    @Published private(set) var isRegistered = false
    @Published var isRecordingShortcut = false
    
    // MARK: - Private Properties
    
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var localEventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    /// Callback triggered when the shortcut is activated.
    var onShortcutActivated: (() -> Void)?
    
    /// Callback for capturing a new shortcut during recording mode.
    var onShortcutCaptured: ((KeyboardShortcut) -> Void)?
    
    // MARK: - Static Hotkey Identifier
    
    private static let hotKeyID = EventHotKeyID(
        signature: OSType(0x4D415350), // "MASP" - Meeting Assistant Shortcut
        id: 1
    )
    
    // MARK: - Initialization
    
    private init() {
        setupSettingsObserver()
    }
    
    
    // Note: Cleanup is handled by AppDelegate.applicationWillTerminate()
    // Cannot use deinit with Task as it would capture self after deallocation
    
    
    // MARK: - Public API
    
    /// Register the global hotkey with the current settings.
    func registerHotKey() {
        let shortcut = AppSettingsStore.shared.keyboardShortcut
        registerHotKey(shortcut)
    }
    
    /// Register a specific keyboard shortcut as a global hotkey.
    /// - Parameter shortcut: The keyboard shortcut to register.
    func registerHotKey(_ shortcut: KeyboardShortcut) {
        unregisterHotKey()
        
        // Convert modifiers to Carbon format
        var carbonModifiers: UInt32 = 0
        if shortcut.modifiers & UInt32(cmdKey) != 0 { carbonModifiers |= UInt32(cmdKey) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { carbonModifiers |= UInt32(shiftKey) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { carbonModifiers |= UInt32(optionKey) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { carbonModifiers |= UInt32(controlKey) }
        
        // Install event handler if not already installed
        if eventHandler == nil {
            installEventHandler()
        }
        
        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            eventHotKeyRef = hotKeyRef
            isRegistered = true
            logger.info("Global shortcut registered: \(shortcut.displayString)")
        } else {
            logger.error("Failed to register hotkey, status: \(status)")
            isRegistered = false
        }
    }
    
    /// Unregister the current global hotkey.
    func unregisterHotKey() {
        if let hotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            eventHotKeyRef = nil
            isRegistered = false
            logger.info("Global shortcut unregistered")
        }
    }
    
    /// Start recording mode to capture a new shortcut.
    func startRecordingShortcut() {
        isRecordingShortcut = true
        unregisterHotKey()
        
        // Monitor for key presses
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil // Consume the event
        }
        
        logger.info("Started recording shortcut")
    }
    
    /// Stop recording mode without saving.
    func stopRecordingShortcut() {
        isRecordingShortcut = false
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // Re-register the existing shortcut
        registerHotKey()
        
        logger.info("Stopped recording shortcut")
    }
    
    // MARK: - Private Methods
    
    private func setupSettingsObserver() {
        // Re-register hotkey when settings change
        AppSettingsStore.shared.$keyboardShortcut
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newShortcut in
                Task { @MainActor in
                    self?.registerHotKey(newShortcut)
                }
            }
            .store(in: &cancellables)
    }
    
    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            // Verify this is our hotkey
            if hotKeyID.id == GlobalShortcutManager.hotKeyID.id {
                Task { @MainActor in
                    GlobalShortcutManager.shared.handleHotKeyActivation()
                }
            }
            
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
    }
    
    private func handleHotKeyActivation() {
        logger.info("Global shortcut activated")
        onShortcutActivated?()
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecordingShortcut else { return }
        
        // Require at least one modifier key
        let modifiers = convertToCarbon(event.modifierFlags)
        guard modifiers != 0 else { return }
        
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        )
        
        // Only accept valid shortcuts
        guard !shortcut.displayString.isEmpty else { return }
        
        onShortcutCaptured?(shortcut)
        stopRecordingShortcut()
    }
    
    /// Convert NSEvent modifier flags to Carbon modifier flags.
    private func convertToCarbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        return carbonModifiers
    }
}
