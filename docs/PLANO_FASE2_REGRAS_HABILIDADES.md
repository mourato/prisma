# Plano de Ação - Fase 2: Regras e Habilidades do Agente

## Objetivo
Corrigir inconsistências e gaps identificados na estrutura de regras e habilidades do agente.

## Contexto
Problemas identificados:
- AGENTS.md não lista todas as 12 habilidades existentes
- skill-creator é redundante com skill-development
- debugging-strategies referencia arquivos inexistentes
- Inconsistência de idioma entre habilidades
- Gaps de cobertura (Keychain, Testing, Combine, Core Data, Instruments)

## Ações Prioritárias

### 2.1 Atualizar AGENTS.md com Todas as Habilidades [Alta Prioridade]
**Arquivo**: `AGENTS.md`

**Contexto**: AGENTS.md linhas 84-90 lista 7 habilidades, mas existem 12 habilidades no total. Faltam: debugging-strategies, skill-creator, skill-development, skills-discovery, git-advanced-workflows.

**Ação**:
Atualizar a seção "Skills Index" do AGENTS.md para listar todas as 12 habilidades existentes.

**Prompt para LLM**:
```
Atualize a seção "Skills Index" do arquivo AGENTS.md para incluir as seguintes habilidades que estão faltando:

Habilidades existentes no .agent/skills/:
1. audio-realtime - Trigger: AVAudioSourceNode, AudioRecorder, ProcessTap
2. debugging-strategies - Trigger: bugs, crash, performance issue
3. documentation - Trigger: DocC comments, API docs
4. git-advanced-workflows - Trigger: rebase, bisect, cherry-pick
5. git-workflow - Trigger: git commit, branches, PRs
6. localization - Trigger: Bundle.module, NSLocalizedString
7. menubar - Trigger: NSStatusItem, NSMenu, NSPopover
8. skill-creator - Trigger: Criar habilidades
9. skill-development - Trigger: Desenvolver plugins
10. skills-discovery - Trigger: Buscar habilidades, registry
11. swift-package-manager - Trigger: Package.swift, SPM
12. swiftui-patterns - Trigger: SwiftUI views, @State, NavigationStack

Mantenha a estrutura existente do arquivo e adicione as habilidades faltantes na ordem alfabética por nome da pasta.
```

**Critérios de Aceitação**:
- [ ] AGENTS.md lista todas as 12 habilidades
- [ ] Triggers corretos para cada habilidade
- [ ] Estrutura do arquivo preservada

---

### 2.2 Mesclar skill-creator em skill-development [Alta Prioridade]
**Arquivos**: `.agent/skills/skill-creator/` e `.agent/skills/skill-development/`

**Contexto**: skill-creator tem 90% de conteúdo idêntico ao skill-development. Manter dois arquivos causa confusão e manutenção duplicada.

**Ação**:
1. Analisar ambos os arquivos
2. Mesclar conteúdo relevante do skill-creator no skill-development
3. Remover pasta skill-creator

**Prompt para LLM**:
```
Analise os arquivos em .agent/skills/skill-creator/ e .agent/skills/skill-development/. Identifique o conteúdo único de skill-creator que não existe em skill-development e adicione ao skill-development. Depois, remova a pasta skill-creator/ completamente.

Crie um resumo das mudanças feitas no skill-development e documente que skill-creator foi mesclado.
```

**Critérios de Aceitação**:
- [ ] Pasta .agent/skills/skill-creator/ removida
- [ ] Conteúdo único preservado em skill-development
- [ ] README.md ou SKILL.md atualizado indicando mesclagem

---

### 2.3 Corrigir Referências Ausentes em debugging-strategies [Média Prioridade]
**Arquivo**: `.agent/skills/debugging-strategies/SKILL.md`

**Contexto**: O arquivo referencia arquivos que não existem:
- references/debugging-tools-guide.md
- references/performance-profiling.md
- references/production-debugging.md
- assets/debugging-checklist.md
- assets/common-bugs.md
- scripts/debug-helper.ts

**Ações**:
1. Criar os arquivos referenciados OU
2. Remover as referências do SKILL.md

**Recomendação**: Criar arquivos vazios/placeholders com templates básicos.

**Prompt para LLM**:
```
Crie os seguintes arquivos referenciados em .agent/skills/debugging-strategies/ que estão faltando. Cada arquivo deve ter apenas um template básico:

1. references/debugging-tools-guide.md:
```markdown
# Guia de Ferramentas de Debug

## Instruments
- Descrição de como usar Instruments

## Xcode Debugger
- Breakpoints, LLDB commands

## Console.app
- Como filtrar logs
```

2. references/performance-profiling.md:
```markdown
# Profiling de Performance

## Time Profiler
- Como usar

## Memory Debugger
- Identificar memory leaks
```

3. references/production-debugging.md:
```markdown
# Debug em Produção

## Logs
- Onde encontrar

## Crash Reports
- Symbolicating
```

4. assets/debugging-checklist.md:
```markdown
# Checklist de Debug

## Antes de Começar
- [ ] Reproduzir o problema
- [ ] Documentar steps

## Verificações Comuns
- [ ] Memory
- [ ] Performance
- [ ] Network
```

5. assets/common-bugs.md:
```markdown
# Bugs Comuns

## SwiftUI
- State não atualizando

## Concurrency
- Race conditions
```

Todos os arquivos devem ter formato Markdown válido e estrutura básica.
```

**Critérios de Aceitação**:
- [ ] references/created com 3 arquivos
- [ ] assets/created com 2 arquivos
- [ ] debugging-strategies/SKILL.md atualizado com links corretos

---

### 2.4 Padronizar Idioma das Habilidades [Média Prioridade]
**Pasta**: `.agent/skills/`

**Contexto**: Habilidades estão em idiomas mistos:
- git-workflow: Português
- git-advanced-workflows: Inglês
- debugging-strategies: Inglês
- audio-realtime: Português

**Ação**:
Decidir política de idioma e padronizar. Recomendação: inglês como padrão.

**Prompt para LLM**:
```
Liste todos os arquivos .md em .agent/skills/ e identifique quais estão em português e quais estão em inglês. Sugira uma política de idioma (inglês ou português) e forneça um plano para traduzir os arquivos que estão fora do padrão escolhido.
```

**Critérios de Aceitação**:
- [ ] Inventário de idiomas criado
- [ ] Política de idioma definida
- [ ] Arquivos traduzidos (se aplicável)

---

### 2.5 Criar Habilidade Keychain-Security [Média Prioridade]
**Pasta**: `.agent/skills/keychain-security/`

**Contexto**: A regra security.md menciona Keychain, mas não há habilidade específica para guiar agentes sobre padrões de segurança do projeto.

**Ação**:
Criar nova habilidade keychain-security com padrões do projeto.

**Prompt para LLM**:
```
Crie uma nova habilidade em .agent/skills/keychain-security/ com os seguintes arquivos:

1. SKILL.md:
```markdown
# Keychain & Security Skill

## Triggers
- KeychainManager, KeychainProvider, storeSecret, retrieveSecret

## Padrões do Projeto

### Armazenamento de Secrets
- API keys: usar KeychainManager.store() com enum KeychainKey
- Tokens: usar DefaultKeychainProvider

### Keys Definidas
- aiAPIKey: chave da API de IA
- legacyApiKey: chave legacy (deprecated)

### Erros Comuns
- errSecItemNotFound: chave não encontrada
- errSecAuthFailed: falha de autenticação

## Exemplos

### Correct
```swift
try? KeychainManager.store(apiKey, for: .aiAPIKey)
let key = try KeychainManager.retrieve(for: .aiAPIKey)
```

### Incorrect
```swift
UserDefaults.standard.set(apiKey, forKey: "apiKey") // Never!
```
```

2. README.md:
```markdown
# keychain-security

Guia para uso seguro de Keychain no projeto.
```

Mantenha a estrutura consistente com outras habilidades do projeto.
```

**Critérios de Aceitação**:
- [ ] Pasta .agent/skills/keychain-security/ criada
- [ ] SKILL.md criado com conteúdo relevante
- [ ] README.md criado

---

### 2.6 Criar Habilidade Testing-XCTest [Média Prioridade]
**Pasta**: `.agent/skills/testing-xctest/`

**Contexto**: A regra testing.md existe, mas não há habilidade condicional para guiar agentes sobre padrões de teste do projeto.

**Ação**:
Criar nova habilidade testing-xctest.

**Prompt para LLM**:
```
Crie uma nova habilidade em .agent/skills/testing-xctest/ com os seguintes arquivos:

1. SKILL.md:
```markdown
# Testing & XCTest Skill

## Triggers
- XCTest, @Test, testMethod, XCTAssert, mock, stub

## Padrões do Projeto

### Estrutura de Testes
- Arquivo de teste: {Component}Tests.swift
- Localização: Packages/MeetingAssistantCore/Tests/
- Naming: test{Method}_{Condition}

### Mocks Disponíveis
- MockRecordingService: para RecordingManager
- MockAudioRecorder: para AudioRecorder
- MockTranscriptionClient: para TranscriptionClient
- MockPostProcessingService: para PostProcessingService

### Boas Práticas
- @MainActor em todos os testes de ViewModel
- async/await para operações assíncronas
- Given-When-Then pattern

## Exemplo

```swift
@Test func testStartRecording_Success() async {
    // Given
    let mock = MockRecordingService()
    mock.startRecordingReturnValue = true
    
    // When
    await sut.startRecording()
    
    // Then
    XCTAssertTrue(mock.startRecordingCalled)
}
```
```

2. README.md:
```markdown
# testing-xctest

Guia para escrever testes unitários no projeto.
```

Mantenha a estrutura consistente com outras habilidades do projeto.
```

**Critérios de Aceitação**:
- [ ] Pasta .agent/skills/testing-xctest/ criada
- [ ] SKILL.md criado com padrões do projeto
- [ ] README.md criado
- [ ] Mocks existentes documentados

---

## Resumo de Ações

| Prioridade | Ação | Esforço Estimado | Arquivos |
|------------|------|------------------|----------|
| Alta | Atualizar AGENTS.md | 15 min | AGENTS.md |
| Alta | Mesclar skill-creator | 30 min | skill-creator/, skill-development/ |
| Média | Criar referências debugging | 45 min | references/, assets/ |
| Média | Padronizar idioma | 2h | Múltiplos arquivos |
| Média | Criar habilidade Keychain | 30 min | keychain-security/ |
| Média | Criar habilidade Testing | 30 min | testing-xctest/ |

## Checklist de Conclusão

- [ ] AGENTS.md lista todas as 12 habilidades
- [ ] skill-creator mesclado e removido
- [ ] Referências de debugging-strategies criadas
- [ ] Política de idioma definida
- [ ] Habilidade keychain-security criada
- [ ] Habilidade testing-xctest criada

## Comandos Úteis

```bash
# Listar todas as habilidades
ls -la .agent/skills/

# Verificar referências em debugging-strategies
grep -r "\[" .agent/skills/debugging-strategies/ | grep -E "\.(md|ts)" | head -20

# Verificar idioma dos arquivos
head -5 .agent/skills/*/*.md
```
