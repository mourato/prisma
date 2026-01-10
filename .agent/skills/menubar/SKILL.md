# Menu Bar Applications

> **Skill Condicional** - Ativada quando trabalhando com NSStatusItem

## Visão Geral

Padrões específicos para aplicações menu bar no macOS usando NSStatusItem.

## Quando Usar

Ative esta skill quando detectar:
- `NSStatusItem`
- `NSStatusBar`
- `NSMenu`
- `NSStatusBarButton`
- `popover`

## Conceitos-Chave

### Context Menu Behavior

**Right-click** no `NSStatusItem` deve mostrar menu de contexto:

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
        closePopover() // Fecha popover antes de mostrar menu
        showContextMenu(sender)
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = createContextMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
```

### Dynamic Menu Items

Armazene referências para atualizar títulos:

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

Atualize estado da UI junto:

```swift
func updateStatusIcon(isRecording: Bool) {
    let iconName = isRecording ? "record.circle.fill" : "circle"
    statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    statusItem.button?.toolTip = isRecording ?
        NSLocalizedString("recording.in_progress", bundle: .module, comment: "") : nil
}
```

## Patterns Comuns

### Menu Bar com Popover

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

            // Right-click para menu de contexto
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

## Armadilhas Comuns

1. **Popover travado** - Sempre chame `closePopover()` antes de outras ações
2. **Menu não atualiza** - Mantenha referências aos itens dinâmicos
3. **Click fora** - Configure `popover.behavior = .transient`
4. **Memory leaks** - Use `[weak self]` em closures

## Referências

- [MenuBarView.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Views/MenuBarView.swift)
- [Apple Status Bar Guide](https://developer.apple.com/documentation/appkit/nsstatusitem)
