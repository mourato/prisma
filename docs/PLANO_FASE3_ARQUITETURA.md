# Plano de Ação - Fase 3: Arquitetura e Código Core

## Objetivo
Corrigir violações de arquitetura e padrões de código identificados na análise.

## Contexto
Problemas críticos identificados:
- Singletons `.shared` em ViewModels (3 arquivos)
- Código de debug hardcoded em AudioRecorder.swift
- `preconditionFailure` em produção
- Funções longas (>120 linhas)
- `try?` silenciando erros
- Closures sem @Sendable

Avaliação geral: 75/100

## Ações Prioritárias

### 3.1 Remover Singletons `.shared` de ViewModels [Crítica]
**Arquivos**: 
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/RecordingViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/AISettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/GeneralSettingsViewModel.swift`

**Contexto**: ViewModels usam `.shared` como default em construtores, dificultando testes.

**Ação**:
Remover defaults com singletons e forçar injeção explícita.

**Prompt para LLM - RecordingViewModel**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/RecordingViewModel.swift, linha 66:

```swift
public init(recordingManager: some RecordingServiceProtocol = RecordingManager.shared) {
```

Remova o default `RecordingManager.shared` para que o construtor exija injeção explícita:

```swift
public init(recordingManager: some RecordingServiceProtocol) {
    self.recordingManager = recordingManager
}
```

Depois, atualize todos os lugares que chamam `RecordingViewModel()` para passar `RecordingManager.shared` explicitamente. Busque por usages em:
- Views/Settings/Tabs/GeneralSettingsTab.swift
- Views/MenuBarView.swift
- Outros arquivos que instanciam RecordingViewModel

Forneça a lista de mudanças necessárias em cada arquivo.
```

**Prompt para LLM - AISettingsViewModel**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/AISettingsViewModel.swift, linhas 22-26:

```swift
public init(
    settings: AppSettingsStore = .shared,
    keychain: KeychainProvider = DefaultKeychainProvider(),
    session: URLSession = .shared
) {
```

Remova o default `.shared` de `settings` e mantenha apenas `DefaultKeychainProvider()`:

```swift
public init(
    settings: AppSettingsStore,
    keychain: KeychainProvider = DefaultKeychainProvider(),
    session: URLSession = .shared
) {
```

Depois, atualize todos os lugares que chamam `AISettingsViewModel()` para passar `AppSettingsStore.shared` explicitamente.
```

**Prompt para LLM - GeneralSettingsViewModel**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/GeneralSettingsViewModel.swift, linha 7:

```swift
private let settingsStore = AppSettingsStore.shared
```

Mude para propriedade injetada no construtor:

```swift
private let settingsStore: AppSettingsStore

public init(settingsStore: AppSettingsStore = .shared) {
    self.settingsStore = settingsStore
}
```

**Critérios de Aceitação**:
- [ ] RecordingViewModel.init exige RecordingManager explícito
- [ ] AISettingsViewModel.init exige AppSettingsStore explícito
- [ ] GeneralSettingsViewModel usa injeção por construtor
- [ ] Todos os callers atualizados

---

### 3.2 Remover Código de Debug Hardcoded [Crítica]
**Arquivo**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift`

**Contexto**: Linhas 215-320 contêm código de debug com caminho absoluto do usuário:
```swift
let logPath = "/Users/usuario/Documents/Repos/my-meeting-assistant/.cursor/debug.log"
```

**Ação**:
Remover ou encapsular em `#if DEBUG`.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift, há código de debug hardcoded entre as linhas 215-320. Identifique todo o código relacionado a logging de debug e:

1. Se o código não é mais necessário, remova-o completamente
2. Se ainda é necessário, encapsule com `#if DEBUG` e use `FileManager.default.urls(for: .cachesDirectory)` em vez de caminho absoluto

Forneça o código modificado ou a região a ser removida.
```

**Critérios de Aceitação**:
- [ ] Caminho absoluto "/Users/usuario/..." removido
- [ ] Código de debug encapsulado ou removido
- [ ] Arquivo compila sem erros

---

### 3.3 Corrigir `preconditionFailure` em Produção [Alta]
**Arquivo**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Models/AppSettings.swift`

**Contexto**: Linha 40 usa `preconditionFailure` que causa crash em produção:
```swift
static let meetingNotes = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? {
    preconditionFailure("Invalid UUID string for meetingNotes")
}()
```

**Ação**:
Substituir por tratamento de erro adequado.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Models/AppSettings.swift, linha 40:

```swift
static let meetingNotes = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? {
    preconditionFailure("Invalid UUID string for meetingNotes")
}()
```

Substitua por uma abordagem que não cause crash em produção:

```swift
static let meetingNotes: UUID = {
    guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
        // Em produção, use um UUID fallback conhecido
        // Em debug, falhe para identificar o problema
        assertionFailure("Invalid UUID string for meetingNotes")
        return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }
    return uuid
}()
```

Isso permite que o app continue funcionando mesmo com UUID inválido, mas alerta em debug.
```

**Critérios de Aceitação**:
- [ ] `preconditionFailure` substituído por `assertionFailure`
- [ ] Fallback implementado
- [ ] App não crasha em produção

---

### 3.4 Extrair Funções Longas em AudioRecorder [Média]
**Arquivo**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift`

**Contexto**: 
- `connectSystemAudio()`: ~120 linhas (linha 214)
- `configureWorker()`: ~80 linhas (linha 323)
- `createSystemSourceNode()`: ~67 linhas (linha 401)

**Ação**:
Extrair sub-funções menores.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift, a função `connectSystemAudio()` (linha ~214) tem ~120 linhas. Extraia as seguintes sub-funções:

1. `configureSystemFormat()` - configura AudioStreamBasicDescription
2. `setupSystemTap()` - configura tap no sistema
3. `connectSystemEngine()` - conecta engine ao output

Cada função deve:
- Ter no máximo 30 linhas
- Ter documentação /// 
- Ser chamada sequencialmente em connectSystemAudio()

Forneça o código das novas funções e como connectSystemAudio() deve ser modificado.
```

**Critérios de Aceitação**:
- [ ] connectSystemAudio() < 80 linhas
- [ ] configureWorker() < 50 linhas
- [ ] Novas funções documentadas
- [ ] Arquivo compila

---

### 3.5 Substituir `try?` por Tratamento de Erro [Média]
**Arquivos**: 
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Models/AppSettings.swift` (linha 103)
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/RecordingManager.swift` (linha 509)

**Contexto**: `try?` silencia erros que deveriam ser tratados ou propagados.

**Ação**:
Substituir por `do-catch` quando apropriado ou propagar erro.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Models/AppSettings.swift, linha 103:

```swift
try? KeychainManager.store(self._legacyApiKey, for: .aiAPIKey)
```

Substitua por tratamento adequado:

```swift
do {
    try KeychainManager.store(self._legacyApiKey, for: .aiAPIKey)
} catch {
    AppLogger.shared.logError("Failed to store legacy API key", category: .settings)
    // Decida: propagar erro ou registrar e continuar?
    // Para preferências, registrar e continuar é geralmente aceitável
}
```

Faça o mesmo para RecordingManager.swift linha 509:
```swift
try? await Task.sleep(for: .seconds(Constants.statusResetDelay))
```

Avalie se o sleep é crítico. Se não for, pode usar `try?`. Se for, propague o erro.
```

**Critérios de Aceitação**:
- [ ] AppSettings.swift: erro registrado, não silenciado
- [ ] RecordingManager.swift: avaliação feita e tratada apropriadamente
- [ ] Logging adequado

---

### 3.6 Adicionar @Sendable em Closures [Média]
**Arquivo**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/TranscriptionImportViewModel.swift`

**Contexto**: Linha 43 tem closure sem anotação @Sendable.

**Ação**:
Adicionar @Sendable quando apropriado.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/TranscriptionImportViewModel.swift, linha 43:

```swift
provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
```

Verifique se esta closure é chamada entre threads diferentes. Se sim, adicione @Sendable:

```swift
provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] @Sendable item, _ in
```

Também verifique outras closures no arquivo e marque todas com @Sendable quando apropriado.
```

**Critérios de Aceitação**:
- [ ] Closures têm @Sendable quando necessário
- [ ] Código compila

---

### 3.7 Corrigir force_unwrapping Violations [Média]
**Arquivos**: 
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift`

**Contexto**: SwiftLint reporta 15+ violações de force_unwrapping.

**Ação**:
Substituir `!` por `guard let` ou `if let`.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift, identifique todos os force_unwrapping (!) e substitua por tratamento adequado.

Exemplo:
```swift
// Antes
return buffer.floatChannelData!.pointee

// Depois
guard let floatData = buffer.floatChannelData else {
    return 0.0
}
return floatData.pointee
```

Liste todas as linhas com force_unwrapping e forneça a versão corrigida de cada uma.
```

**Critérios de Aceitação**:
- [ ] force_unwrapping reduzido ao mínimo
- [ ] Tratamento adequado com guard/if let
- [ ] SwiftLint passa para esta regra

---

## Resumo de Ações

| Prioridade | Ação | Esforço Estimado | Arquivos |
|------------|------|------------------|----------|
| Crítica | Remover singletons de ViewModels | 1h | 3 ViewModels + callers |
| Crítica | Remover código de debug | 15 min | AudioRecorder.swift |
| Alta | Corrigir preconditionFailure | 10 min | AppSettings.swift |
| Média | Extrair funções longas | 2h | AudioRecorder.swift |
| Média | Tratar try? adequadamente | 30 min | AppSettings, RecordingManager |
| Média | Adicionar @Sendable | 15 min | TranscriptionImportViewModel |
| Média | Corrigir force_unwrapping | 1h | AudioBufferQueue, AudioRecorder |

## Checklist de Conclusão

- [ ] RecordingViewModel exige injeção explícita
- [ ] AISettingsViewModel exige injeção explícita
- [ ] GeneralSettingsViewModel usa DI por construtor
- [ ] Código de debug removido/encapsulado
- [ ] preconditionFailure → assertionFailure
- [ ] Funções de AudioRecorder extraídas
- [ ] try? tratados adequadamente
- [ ] @Sendable adicionados
- [ ] force_unwrapping corrigidos

## Comandos Úteis

```bash
# Verificar singletons em ViewModels
grep -n "\.shared" Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/ViewModels/

# Verificar force_unwrapping
grep -n "!" Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift

# Verificar código de debug
grep -n "debug.log\|\.cursor\|/Users/usuario" Packages/MeetingAssistantCore/Sources/

# Rodar lint
./scripts/lint.sh
```
