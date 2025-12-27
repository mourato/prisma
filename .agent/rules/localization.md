---
trigger: model_decision
description: When working with the interface (UI) of the app.
---

# Resource Loading
- Use `Bundle.module` em Swift Packages; `Bundle.main` não encontrará recursos
- Use `NSLocalizedString("Key", bundle: .module, comment: "...")` para localização em código
- Em SwiftUI, use `Text("Key", bundle: .module)` quando o bundle não for inferido automaticamente

# String Management
- Nunca hardcode strings de UI — extraia para `Localizable.strings`
- Use chaves descritivas em snake_case (ex: `settings_api_key_placeholder`)

# Accessibility (VoiceOver)
- TODOS os `accessibilityDescription` DEVEM usar `NSLocalizedString` com o bundle correto
- Convenção de chaves: `*.accessibility.*` (ex: `menubar.accessibility.recording`)
- Descreva *propósito* ou *estado*, não apenas rótulos (ex: "Recording in progress" vs "Recording")

# Cross-Module Bundle
- Use o padrão `Bundle.safeModule` para acesso entre App e Frameworks
- Armazene o bundle em `lazy var` para evitar chamadas repetidas