# Plano de Ação - Fase 4: Qualidade e Testes

## Objetivo
Corrigir problemas de qualidade de código e testes identificados na análise.

## Contexto
Problemas identificados:
- 4 testes falhando (18/22 passando = 82%)
- 80+ warnings SwiftLint, 1 error crítico (empty_count)
- Cobertura de testes ~40-50%
- Mocks inadequados para alguns cenários
- 3 testes falhando por localização (inglês vs português)

## Ações Prioritárias

### 4.1 Corrigir empty_count Error Crítico [Crítica]
**Arquivo**: `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift`

**Contexto**: Linha 75 viola regra empty_count do SwiftLint:
```swift
buffer.pointer.count == 0  // Error: use isEmpty instead of count == 0
```

**Ação**:
Substituir por `isEmpty`.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift, linha 75:

```swift
buffer.pointer.count == 0
```

Substitua por:

```swift
buffer.pointer.isEmpty
```

Verifique se há outras ocorrências desta violação no arquivo e corrija todas.
```

**Critérios de Aceitação**:
- [ ] Error empty_count corrigido
- [ ] SwiftLint passa sem errors
- [ ] Arquivo compila

---

### 4.2 Corrigir Testes de Localização [Crítica]
**Arquivo**: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingViewModelTests.swift`

**Contexto**: 3 testes falham porque comparam strings em inglês vs português:
- `testInitialState`: "Waiting for meeting" != "Aguardando reunião"
- `testStartRecording`: "Recording..." != "Gravando..."
- `testStopRecording`: "Transcribing..." != "Transcrevendo..."

**Ação**:
Modificar o RecordingViewModel para expor statusText de forma testável, ou usar NSLocalizedString nos testes.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingViewModelTests.swift, os testes comparam strings hardcoded em inglês com strings em português do app.

3 opções de correção:

**Opção A**: Usar NSLocalizedString nos testes (recomendado)
```swift
// Antes
XCTAssertEqual(sut.statusText, "Waiting for meeting")

// Depois
XCTAssertEqual(sut.statusText, NSLocalizedString("Waiting for meeting", comment: "Initial state"))
```

**Opção B**: Expor enum de estado em vez de string
```swift
enum RecordingStatus {
    case waitingForMeeting
    case recording
    case transcribing
}
```

**Opção C**: Injetar localization provider no ViewModel

Analise o RecordingViewModel e sugira qual opção é melhor para este projeto. Forneça o código modificado para a opção escolhida.
```

**Critérios de Aceitação**:
- [ ] testInitialState passa
- [ ] testStartRecording passa
- [ ] testStopRecording passa
- [ ] Padrão consistente para futuros testes

---

### 4.3 Corrigir testStartRecording_Success [Alta]
**Arquivo**: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTests.swift`

**Contexto**: Teste falha porque mock não está configurado corretamente:
```
testStartRecording_Success: XCTAssertTrue failed - mockSystem.startRecordingCalled é false
```

**Ação**:
Revisar mock configuration para system recorder.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTests.swift, linha 89, o teste `testStartRecording_Success` falha.

Analise o RecordingManager e MockRecordingService para entender:
1. Como o RecordingManager decide qual recorder usar (system vs microphone)
2. Se o mock está configurado para o recorder correto
3. Se o estado do manager está consistente antes de chamar startRecording

Forneça o código corrigido do teste.
```

**Critérios de Aceitação**:
- [ ] testStartRecording_Success passa
- [ ] Mock configurado corretamente
- [ ] Padrão documentado para futuros mocks

---

### 4.4 Adicionar Testes para AudioBufferQueue [Alta]
**Arquivo**: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AudioBufferQueueTests.swift`

**Contexto**: AudioBufferQueue tem 0% de cobertura de teste (componente crítico para áudio real-time).

**Ação**:
Criar testes unitários para AudioBufferQueue.

**Prompt para LLM**:
```
Crie um novo arquivo Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AudioBufferQueueTests.swift com testes para AudioBufferQueue.

O componente AudioBufferQueue gerencia buffers de áudio e deve ser testado para:
1. Inicialização correta
2. Adição de dados
3. Leitura de dados
4. Thread safety (se aplicável)

Use XCTest com async/await. Modele os testes após PartialBufferStateTests.swift que já existe no projeto.

```swift
import XCTest
@testable import MeetingAssistantCore

final class AudioBufferQueueTests: XCTestCase {
    
    // Tests aqui
}
```

Forneça pelo menos 5 testes cobrindo os cenários principais.
```

**Critérios de Aceitação**:
- [ ] AudioBufferQueueTests.swift criado
- [ ] Pelo menos 5 testes
- [ ] Testes passam
- [ ] Código compila

---

### 4.5 Corrigir force_unwrapping Violations [Média]
**Arquivos**: 
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift`

**Contexto**: 15+ violações de force_unwrapping reportadas pelo SwiftLint.

**Ação**:
Substituir `!` por `guard let`/`if let`.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift, identifique e corrija todas as violações de force_unwrapping (!).

Liste cada ocorrência com:
1. Linha
2. Código atual
3. Código corrigido

Exemplo de correção:
```swift
// Antes (linha 45)
return buffer.floatChannelData!.pointee

// Depois
guard let floatData = buffer.floatChannelData else {
    return 0.0
}
return floatData.pointee
```
```

**Critérios de Aceitação**:
- [ ] force_unwrapping reduzido ao mínimo
- [ ] SwiftLint passa para esta regra
- [ ] Tratamento adequado de Optional

---

### 4.6 Melhorar Mocks Inadequados [Média]
**Arquivo**: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Mocks.swift`

**Contexto**:
- MockStorageService não implementa `loadTranscriptions()` com dados mockados
- Falta MockNotificationService
- MockTranscriptionClient não expõe call tracking para todos os métodos

**Ação**:
Melhorar mocks existentes e criar novos.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/Mocks.swift, melhore os mocks existentes:

1. **MockStorageService**: Adicione propriedade `mockTranscriptions` e implemente `loadTranscriptions()` retornando esses dados:
```swift
final class MockStorageService: StorageService {
    var mockTranscriptions: [Transcription] = []
    
    func loadTranscriptions() async throws -> [Transcription] {
        return mockTranscriptions
    }
}
```

2. **MockNotificationService**: Crie nova classe para testar notificações:
```swift
final class MockNotificationService: NotificationService {
    var pendingNotifications: [String] = []
    
    func requestPermission() async -> Bool { true }
    
    func showRecordingStarted() {
        pendingNotifications.append("recordingStarted")
    }
}
```

3. **MockTranscriptionClient**: Adicione call tracking:
```swift
final class MockTranscriptionClient: TranscriptionClient {
    var transcribeCallCount = 0
    var lastTranscribeParams: (url: URL, options: TranscriptionOptions)?
}
```

Forneça o código modificado completo para cada mock.
```

**Critérios de Aceitação**:
- [ ] MockStorageService tem mockTranscriptions
- [ ] MockNotificationService criado
- [ ] MockTranscriptionClient tem call tracking
- [ ] Mocks compilam

---

### 4.7 Corrigir Funções Longas (line_length) [Média]
**Arquivos**:
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift`
- `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/RecordingManager.swift`

**Contexto**: 45+ violações de line_length (linhas com 120-173 caracteres).

**Ação**:
Dividir linhas longas em múltiplas linhas.

**Prompt para LLM**:
```
No arquivo Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift, identifique as linhas que excedem 120 caracteres e reformatelas.

Use as regras do .swiftformat para quebrar linhas:
- Quebrar antes do primeiro parâmetro em chamadas de função
- Indentar parâmetros em novas linhas
- Usar trailing commas

Exemplo:
```swift
// Antes (156 caracteres)
let result = someVeryLongFunctionName(parameter1: value1, parameter2: value2, parameter3: value3, parameter4: value4)

// Depois (89 caracteres)
someVeryLongFunctionName(
    parameter1: value1,
    parameter2: value2,
    parameter3: value3,
    parameter4: value4
)
```

Liste as linhas problemáticas e forneça a versão corrigida.
```

**Critérios de Aceitação**:
- [ ] line_length violations reduzidas significativamente
- [ ] Código mais legível
- [ ] SwiftLint passa com menos warnings

---

### 4.8 Adicionar Testes para Error Handling [Média]
**Pasta**: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`

**Contexto**: Error handling paths não estão sendo testados.

**Ação**:
Adicionar testes para cenários de erro.

**Prompt para LLM**:
```
Adicione testes de error handling ao arquivo RecordingManagerTests.swift:

1. **testStartRecording_FailsWhenSystemRecorderFails**
2. **testStopRecording_HandlesErrorGracefully**
3. **testTranscription_FailsWithInvalidURL**

Use o padrão:
```swift
@Test func testStartRecording_FailsWhenSystemRecorderFails() async {
    // Given
    mockSystem.startRecordingReturnValue = false
    mockSystem.startRecordingError = RecordingManagerError.recorderNotAvailable
    
    // When
    do {
        try await sut.startRecording()
        XCTFail("Expected error to be thrown")
    } catch {
        // Then
        XCTAssertTrue(error is RecordingManagerError)
    }
}
```

Forneça os 3 testes completos.
```

**Critérios de Aceitação**:
- [ ] 3 novos testes de error handling
- [ ] Testes passam
- [ ] Error types adequados

---

### 4.9 Configurar Xcode Test Scheme [Baixa]
**Contexto**: Testes atualmente só funcionam com `swift test`, não com Xcode.

**Ação**:
Criar ou configurar Xcode test scheme.

**Prompt para LLM**:
```
Verifique se existe um test scheme no Xcode para o projeto. O arquivo MeetingAssistant.xcodeproj/project.pbxproj deve ter um XCTestScheme.

Se não existir, sugira como criar um scheme de teste que funcione tanto com `xcodebuild test` quanto com `swift test`.

Liste os comandos necessários:
```bash
# Criar scheme
xcodebuild -create-project -path . -scheme MeetingAssistant

# Listar schemes
xcodebuild -list
```

Forneça instruções para configurar o scheme corretamente.
```

**Critérios de Aceitação**:
- [ ] Testes funcionam com xcodebuild test
- [ ] Testes funcionam com swift test
- [ ] Documentação atualizada

---

## Resumo de Ações

| Prioridade | Ação | Esforço Estimado | Arquivos |
|------------|------|------------------|----------|
| Crítica | Corrigir empty_count error | 5 min | AudioBufferQueue.swift |
| Crítica | Corrigir testes de localização | 30 min | RecordingViewModelTests.swift |
| Alta | Corrigir testStartRecording_Success | 15 min | RecordingManagerTests.swift |
| Alta | Adicionar testes AudioBufferQueue | 1h | AudioBufferQueueTests.swift |
| Média | Corrigir force_unwrapping | 1h | AudioBufferQueue, AudioRecorder |
| Média | Melhorar mocks | 45 min | Mocks.swift |
| Média | Corrigir line_length | 1h | AudioRecorder, RecordingManager |
| Média | Adicionar testes error handling | 30 min | RecordingManagerTests.swift |
| Baixa | Configurar Xcode test scheme | 15 min | project.pbxproj |

## Checklist de Conclusão

- [ ] empty_count error corrigido
- [ ] 4/4 testes de RecordingViewModel passam
- [ ] testStartRecording_Success passa
- [ ] AudioBufferQueueTests.swift criado
- [ ] force_unwrapping corrigido
- [ ] Mocks melhorados
- [ ] line_length melhorado
- [ ] Testes de error handling adicionados
- [ ] Xcode test scheme configurado

## Comandos Úteis

```bash
# Rodar todos os testes
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS'

# Rodar testes específicos
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -only-testing:MeetingAssistantCoreTests/RecordingViewModelTests

# Verificar cobertura
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant CODE_SIGN_IDENTITY="-" ENABLE_CODE_COVERAGE=YES

# Rodar lint
./scripts/lint.sh
```

## Métricas Alvo

| Métrica | Atual | Meta |
|---------|-------|------|
| Testes passando | 18/22 (82%) | 22/22 (100%) |
| Cobertura | ~40% | 60% |
| Violações SwiftLint | 80+ | <20 |
| Errors SwiftLint | 1 | 0 |
