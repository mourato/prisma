---
name: Menu Bar Applications
description: This skill should be used when working with "NSStatusItem", "NSStatusBar", "menu bar apps", "popover", or implementing macOS status bar functionality.
---

# Menu Bar Applications

## Overview

Specific patterns for macOS menu bar applications using NSStatusItem.

## When to Use

Activate this skill when working with:
- `NSStatusItem`
- `NSStatusBar`
- `NSMenu`
- `NSStatusBarButton`
- `NSPopover`
- Menu bar app development

## Key Concepts

### Context Menu Behavior

**Right-click** on `NSStatusItem` should show context menu:

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
        closePopover() // Close popover before showing menu
        showContextMenu(sender)
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = createContextMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
```

### Dynamic Menu Items

Store references to update titles dynamically:

```swift
class MenuBarController {
    private var startStopMenuItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var isRecording = false

    func createMenu() {
        startStopMenuItem = createMenuItem(
            key: "menubar.recording.toggle",
            action: #selector(toggleRecording)
        )
        statusMenuItem = createMenuItem(
            key: "menubar.status",
            action: nil
        )

        let menu = NSMenu()
        menu.addItem(startStopMenuItem)
        menu.addItem(statusMenuItem)
        statusItem.menu = menu
    }

    private func createMenuItem(key: String, action: Selector?) -> NSMenuItem {
        NSMenuItem(
            title: NSLocalizedString(key, bundle: .module, comment: ""),
            action: action,
            keyEquivalent: ""
        )
    }

    func updateUIState(isRecording: Bool) {
        self.isRecording = isRecording
        let titleKey = isRecording ? "menubar.recording.stop" : "menubar.recording.start"
        startStopMenuItem.title = NSLocalizedString(titleKey, bundle: .module, comment: "")
        updateStatusIcon(isRecording: isRecording)
    }
}
```

### State Reflection

Update UI state together with icon and tooltip:

```swift
func updateStatusIcon(isRecording: Bool) {
    let iconName = isRecording ? "record.circle.fill" : "circle"
    statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    statusItem.button?.toolTip = isRecording ?
        NSLocalizedString("recording.in_progress", bundle: .module, comment: "") : nil
}
```

## Common Patterns

### Menu Bar with Popover

```swift
final class MeetingAssistantMenuBar {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var recordingManager: RecordingManager

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        setup()
    }

    private func setup() {
        popover.contentViewController = MenuBarViewController()
        popover.behavior = .transient

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: nil)
            button.action = #selector(togglePopover)
            button.target = self

            // Right-click for context menu
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

## Common Pitfalls

1. **Stuck popover** - Always call `closePopover()` before other actions
2. **Menu doesn't update** - Keep references to dynamic menu items
3. **Click outside** - Configure `popover.behavior = .transient`
4. **Memory leaks** - Use `[weak self]` in closures

## References

- [MenuBarView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/MenuBarView.swift)
- [Apple Status Bar Guide](https://developer.apple.com/documentation/appkit/nsstatusitem)
