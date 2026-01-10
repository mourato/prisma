# Localização e Acessibilidade

> **Skill Condicional** - Ativada quando trabalhando com interface de usuário

## Visão Geral

Guia completo de internacionalização (i18n) e acessibilidade (a11y) para o Meeting Assistant.

## Quando Usar

Ative esta skill quando detectar:
- `Bundle.module`
- `NSLocalizedString`
- `Text("Key", bundle: .module)`
- `accessibilityDescription`
- `.accessibilityHint()`
- `.accessibilityLabel()`

## Conceitos-Chave

### Resource Loading

**CRÍTICO**: Use `Bundle.module` em Swift Packages:

```swift
// ✅ CORRETO - Swift Package
Text("settings_api_key_placeholder", bundle: .module)
NSLocalizedString("menubar.accessibility.recording", bundle: .module, comment: "Recording status")

// ❌ ERRADO - Bundle.main não funciona em frameworks
Text("settings_api_key_placeholder", bundle: .main)
```

### Bundle Safe Access

```swift
extension Bundle {
    static var safeModule: Bundle {
        guard let module = Bundle.module else {
            return Bundle.main
        }
        return module
    }
}

// Uso
Text("key", bundle: .safeModule)
```

## Localização

### String Management

**NUNCA** hardcode strings de UI:

```swift
// ❌ ERRADO
Text("Gravar")

// ✅ CORRETO
Text("recording.start", bundle: .module)
```

### Key Convention

Use `snake_case` descritivo:

```swift
// Boas chaves
"recording.start"              // Iniciar gravação
"recording.stop"               // Parar gravação
"recording.in_progress"        // Gravação em andamento
"settings.api_key.placeholder" // Placeholder da API key
```

## Acessibilidade (VoiceOver)

### Descrições de Propósito

Descreva **o que a UI faz**, não apenas labels:

```swift
// ❌ ERRADO - Label, não descrição
Button(action: {}) {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("Microfone")

// ✅ CORRETO - Descrição de propósito
Button(action: {}) {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("recording.start.accessibility".localized)
.accessibilityHint("recording.start.hint.accessibility".localized)
.accessibilityAddTraits(.startsMediaSession)
```

### Key Convention para Acessibilidade

```swift
// Padrão: componente.acao.accessibility
"menubar.recording.start.accessibility" = "Iniciar gravação";
"menubar.recording.stop.accessibility" = "Parar gravação";
"menubar.recording.status.accessibility" = "Status da gravação";
```

## Referências

- [Localizable.strings](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Resources/en.lproj/Localizable.strings)
- [Apple Accessibility Guide](https://developer.apple.com/documentation/accessibility)
