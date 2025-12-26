import SwiftUI

/// Main entry point for the Meeting Assistant app.
/// Runs as a menu bar application without a dock icon.
@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar app - no main window
        Settings {
            SettingsView()
        }
    }
}

/// App delegate for menu bar setup and lifecycle management.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var contextMenu: NSMenu?
    private var recordingManager = RecordingManager.shared
    private var shortcutManager = GlobalShortcutManager.shared
    private var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupContextMenu()
        setupEventMonitor()
        setupGlobalShortcut()
        
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        shortcutManager.unregisterHotKey()
    }
    
    // MARK: - Global Shortcut Setup
    
    private func setupGlobalShortcut() {
        // Configure shortcut callback to toggle recording
        shortcutManager.onShortcutActivated = { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
        
        // Register the global hotkey
        shortcutManager.registerHotKey()
    }
    
    /// Toggle recording state when global shortcut is activated.
    private func toggleRecording() async {
        if recordingManager.isRecording {
            await recordingManager.stopRecording(transcribe: true)
            updateStatusIcon(isRecording: false)
        } else {
            await recordingManager.startRecording()
            updateStatusIcon(isRecording: true)
        }
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Meeting Assistant")
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(recordingManager)
        )
    }
    
    private func setupContextMenu() {
        contextMenu = NSMenu()
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Configurações...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        contextMenu?.addItem(settingsItem)
        
        // About
        let aboutItem = NSMenuItem(
            title: "Sobre o Meeting Assistant",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        contextMenu?.addItem(aboutItem)
        
        // Separator
        contextMenu?.addItem(NSMenuItem.separator())
        
        // Check for Updates (placeholder)
        let checkUpdatesItem = NSMenuItem(
            title: "Verificar Atualizações...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkUpdatesItem.target = self
        contextMenu?.addItem(checkUpdatesItem)
        
        // Separator
        contextMenu?.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Sair",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        contextMenu?.addItem(quitItem)
    }
    
    private func setupEventMonitor() {
        // Monitor for clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.popover?.performClose(nil)
            }
        }
    }
    
    // MARK: - Click Handling
    
    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
    
    private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            DispatchQueue.main.async {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    private func showContextMenu() {
        guard let menu = contextMenu, let button = statusItem?.button else { return }
        
        // Close popover if open
        popover?.performClose(nil)
        
        // Show context menu
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil  // Reset so left-click works again
    }
    
    private lazy var settingsWindow: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Configurações"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        return window
    }()
    
    // MARK: - Menu Actions
    
    @objc func openSettings() {
        // Close popover first
        popover?.performClose(nil)
        
        // Open settings window
        if !settingsWindow.isVisible {
            settingsWindow.center()
        }
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Handle the standard showSettingsWindow: action
    @objc func showSettingsWindow(_ sender: Any?) {
        openSettings()
    }
    
    @objc private func showAbout() {
        popover?.performClose(nil)
        
        let alert = NSAlert()
        alert.messageText = "Meeting Assistant"
        alert.informativeText = """
            Versão 1.0.0
            
            Transcreva suas reuniões de vídeo automaticamente usando IA.
            
            © 2024 Todos os direitos reservados.
            """
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Meeting Assistant")
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    @objc private func checkForUpdates() {
        popover?.performClose(nil)
        
        let alert = NSAlert()
        alert.messageText = "Verificar Atualizações"
        alert.informativeText = "Você está usando a versão mais recente do Meeting Assistant."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    @objc private func quitApp() {
        // Stop any ongoing recording before quitting
        if recordingManager.isRecording {
            Task {
                await recordingManager.stopRecording(transcribe: false)
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }
    
    // MARK: - Public Methods
    
    /// Update menu bar icon based on recording state.
    func updateStatusIcon(isRecording: Bool) {
        let iconName = isRecording ? "record.circle.fill" : "mic.circle"
        statusItem?.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: isRecording ? "Recording" : "Meeting Assistant"
        )
    }
}
