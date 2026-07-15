# Menu Bar Patterns — code reference

Prisma menu-bar implementation samples. Ownership and non-negotiables live in `../SKILL.md`.

## Context menu behavior

Right-click on `NSStatusItem` should show a context menu:

```swift
class MenuBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    @objc private func handleRightClick(_ sender: NSStatusBarButton) {
        closePopover()
        showContextMenu(sender)
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = createContextMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
```

## Dynamic menu items

Store references to update titles dynamically:

```swift
class MenuBarController {
    private var startStopMenuItem: NSMenuItem!
    private var isRecording = false

    func createMenu() {
        startStopMenuItem = NSMenuItem(
            title: "menubar.recording.toggle".localized,
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        let menu = NSMenu()
        menu.addItem(startStopMenuItem)
        statusItem.menu = menu
    }

    func updateUIState(isRecording: Bool) {
        self.isRecording = isRecording
        let titleKey = isRecording ? "menubar.recording.stop" : "menubar.recording.start"
        startStopMenuItem.title = titleKey.localized
        updateStatusIcon(isRecording: isRecording)
    }
}
```

## Menu bar with popover

```swift
final class MeetingAssistantMenuBar {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    private func setup() {
        popover.contentViewController = MenuBarViewController()
        popover.behavior = .transient

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: nil)
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
}
```

## Floating panel patterns

```swift
final class FloatingRecordingIndicatorController {
    private var panel: NSPanel?

    func show(with hostingView: NSView) {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel
    }
}
```

Window level reference (low → high): `.normal`, `.floating`, `.statusBar`, `.modalPanel`, `.screenSaver` (best for always-visible indicators).

## Reactive state observation

```swift
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()

    private func observeRecordingState() {
        recordingManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                isRecording ? self?.showFloatingIndicator() : self?.hideFloatingIndicator()
            }
            .store(in: &cancellables)
    }
}
```

### Decouple trigger from UI

```swift
// ❌ WRONG — indicator tied to one trigger
func menuBarStartRecording() {
    recordingManager.startRecording()
    showFloatingIndicator()
}

// ✅ CORRECT — observe state reactively
recordingManager.$isRecording
    .sink { [weak self] isRecording in
        isRecording ? self?.show() : self?.hide()
    }
    .store(in: &cancellables)
```

## Common pitfalls

1. Stuck popover — call `closePopover()` before other actions.
2. Menu doesn't update — keep references to dynamic menu items.
3. Click outside — use `popover.behavior = .transient`.
4. Memory leaks — use `[weak self]` in closures.
5. Indicator not visible — use `.screenSaver`, not `.floating`.
6. Indicator tied to trigger — observe state reactively.

## Startup visibility checklist

1. Confirm `NSStatusItem` creation timing (after app launch hooks).
2. Verify icon/title fallback when assets are missing.
3. Test left-click/right-click parity after lifecycle refactors.
4. Verify localized tooltip/title when state labels change.
5. Validate popover recovery after settings-open transitions.
