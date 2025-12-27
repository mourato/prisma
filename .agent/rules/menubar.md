---
trigger: model_decision
description: When working with NSStatusItem or menu bar applications.
---

# Context Menu Behavior
- Right-click no `NSStatusItem` deve mostrar um menu de contexto
- Use o padrão `showContextMenu()` que fecha qualquer popover aberto primeiro

# Dynamic Menu Items
- Armazene referência a itens de menu dinâmicos (`startStopMenuItem`) para atualizar títulos baseado em estado
- Use factory methods como `createMenuItem(key:action:keyEquivalent:)` para reduzir boilerplate

# State Reflection
- Atualize estado da UI (ícones, títulos de menu) juntos usando um único método (ex: `updateStatusIcon(isRecording:)`)