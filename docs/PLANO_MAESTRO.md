# Plano Maestro - Análise Completa do Projeto

## Visão Geral

Este documento consolida todas as ações de melhoria identificadas nas 4 fases de análise do projeto my-meeting-assistant. Use este plano para orquestrar a execução das correções e melhorias em ordem de prioridade.

## Métricas Atuais vs. Meta

| Métrica | Atual | Meta | Prioridade |
|---------|-------|------|------------|
| Testes passando | 18/22 (82%) | 22/22 (100%) | Crítica |
| Cobertura de testes | ~40% | 60% | Alta |
| Violações SwiftLint | 80+ | <20 | Média |
| Errors SwiftLint | 1 | 0 | Crítica |
| Aderência a regras | 75/100 | 90/100 | Média |
| Documentação | 9/10 | 10/10 | Baixa |

---

## Roadmap de Execução

### Fase 0: Preparação (Dia 0)

**Objetivo**: Configurar ambiente e validar estado atual.

```bash
# 1. Backup do estado atual
git status
git branch analysis-$(date +%Y%m%d)

# 2. Rodar lint para validar estado
./scripts/lint.sh > lint-before.txt

# 3. Rodar testes para validar baseline
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' | tee tests-before.txt

# 4. Verificar cobertura atual
# Anotar métricas para comparação posterior
```

**Checklist**:
- [ ] Branch criada para as mudanças
- [ ] lint-before.txt salvo
- [ ] tests-before.txt salvo
- [ ] Métricas anotadas

---

### Fase 1: Correções Críticas (Dias 1-3)

**Objetivo**: Corrigir problemas que impedem release.

| # | Ação | Esforço | Dependência | Arquivos |
|---|------|---------|-------------|----------|
| 1.1 | Corrigir empty_count error | 5 min | Nenhum | AudioBufferQueue.swift |
| 1.2 | Corrigir testes de localização | 30 min | Nenhum | RecordingViewModelTests.swift |
| 1.3 | Corrigir testStartRecording_Success | 15 min | Nenhum | RecordingManagerTests.swift |
| 1.4 | Remover singletons de ViewModels | 1h | Nenhum | 3 ViewModels + callers |
| 1.5 | Remover código de debug hardcoded | 15 min | Nenhum | AudioRecorder.swift |
| 1.6 | Corrigir preconditionFailure | 10 min | Nenhum | AppSettings.swift |

**Comandos de Validação**:
```bash
# Rodar lint após correções
./scripts/lint.sh

# Rodar testes após correções
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS'

# Verificar se todos os testes passam
grep -E "test.*passed|test.*failed" test-output.txt
```

**Critérios de Sucesso**:
- [ ] SwiftLint: 0 errors
- [ ] Testes: 22/22 passando
- [ ] Código de debug removido
- [ ] Singletons eliminados dos ViewModels

---

### Fase 2: Qualidade de Código (Dias 4-7)

**Objetivo**: Melhorar qualidade e reduzir warnings.

| # | Ação | Esforço | Dependência | Arquivos |
|---|------|---------|-------------|----------|
| 2.1 | Extrair funções longas | 2h | Fase 1.4 | AudioRecorder.swift |
| 2.2 | Corrigir force_unwrapping | 1h | Nenhum | AudioBufferQueue, AudioRecorder |
| 2.3 | Tratar try? adequadamente | 30 min | Nenhum | AppSettings.swift, RecordingManager.swift |
| 2.4 | Adicionar @Sendable | 15 min | Nenhum | TranscriptionImportViewModel.swift |
| 2.5 | Corrigir line_length | 1h | Nenhum | AudioRecorder, RecordingManager |

**Comandos de Validação**:
```bash
# Contar violations antes e depois
grep -c "warning\|error" lint-before.txt
grep -c "warning\|error" lint-after.txt

# Verificar redução de warnings
diff lint-before.txt lint-after.txt
```

**Critérios de Sucesso**:
- [ ] SwiftLint warnings: < 30
- [ ] Funções < 60 linhas
- [ ] force_unwrapping: mínimo necessário
- [ ] isEmpty usado em vez de count == 0

---

### Fase 3: Cobertura de Testes (Dias 8-12)

**Objetivo**: Aumentar cobertura e qualidade dos testes.

| # | Ação | Esforço | Dependência | Arquivos |
|---|------|---------|-------------|----------|
| 3.1 | Adicionar testes AudioBufferQueue | 1h | Fase 1.1 | AudioBufferQueueTests.swift |
| 3.2 | Melhorar mocks | 45 min | Nenhum | Mocks.swift |
| 3.3 | Adicionar testes error handling | 30 min | Fase 2.3 | RecordingManagerTests.swift |
| 3.4 | Criar MockNotificationService | 30 min | 3.2 | Mocks.swift |

**Comandos de Validação**:
```bash
# Gerar relatório de cobertura
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" ENABLE_CODE_COVERAGE=YES

# Verificar cobertura por arquivo
xcrun xccov view --report --json xcresult/*.xcresult | jq '.data[0].metrics.codeCoveragePercent'
```

**Critérios de Sucesso**:
- [ ] Cobertura: > 55%
- [ ] AudioBufferQueue: 100%
- [ ] Error handling: testado
- [ ] Mocks: completos e documentados

---

### Fase 4: Documentação (Dias 13-15)

**Objetivo**: Corrigir gaps de documentação.

| # | Ação | Esforço | Dependência | Arquivos |
|---|------|---------|-------------|----------|
| 4.1 | Adicionar LICENSE | 5 min | Nenhum | LICENSE |
| 4.2 | Atualizar AGENTS.md | 15 min | Nenhum | AGENTS.md |
| 4.3 | Habilitar line_length no SwiftLint | 5 min | Fase 2.5 | .swiftlint.yml |
| 4.4 | Atualizar KNOWN_LIMITATIONS | 15 min | Nenhum | KNOWN_LIMITATIONS.md |

**Comandos de Validação**:
```bash
# Verificar se LICENSE existe
ls -la LICENSE

# Verificar AGENTS.md
grep -c "skill\|habilidad" AGENTS.md

# Verificar SwiftLint
swiftlint version
```

**Critérios de Sucesso**:
- [ ] LICENSE existe e é válido
- [ ] AGENTS.md lista todas as 12 habilidades
- [ ] line_length habilitado no SwiftLint
- [ ] KNOWN_LIMITATIONS atualizado

---

### Fase 5: Habilidades do Agente (Dias 16-20)

**Objetivo**: Corrigir gaps nas habilidades do agente.

| # | Ação | Esforço | Dependência | Arquivos |
|---|------|---------|-------------|----------|
| 5.1 | Mesclar skill-creator em skill-development | 30 min | Nenhum | skill-creator/, skill-development/ |
| 5.2 | Criar referências debugging | 45 min | Nenhum | references/, assets/ |
| 5.3 | Padronizar idioma | 2h | Nenhum | Múltiplos arquivos .md |
| 5.4 | Criar habilidade keychain-security | 30 min | Nenhum | keychain-security/ |
| 5.5 | Criar habilidade testing-xctest | 30 min | 3.1 | testing-xctest/ |

**Comandos de Validação**:
```bash
# Listar habilidades
ls -la .agent/skills/ | wc -l

# Verificar se skill-creator foi removido
test -d .agent/skills/skill-creator && echo "EXISTE" || echo "REMOVIDO"

# Verificar referências
grep -r "debugging-tools-guide\|performance-profiling" .agent/skills/debugging-strategies/
```

**Critérios de Sucesso**:
- [ ] skill-creator removido
- [ ] 14 habilidades no total
- [ ] Idioma padronizado
- [ ] keychain-security criada
- [ ] testing-xctest criada

---

### Fase 6: Validação Final (Dia 21)

**Objetivo**: Validar todas as mudanças e preparar para release.

```bash
# 1. Rodar lint completo
./scripts/lint.sh > lint-final.txt

# 2. Rodar todos os testes
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' | tee tests-final.txt

# 3. Gerar relatório de cobertura
xcodebuild test -project MeetingAssistant.xcodeproj -scheme MeetingAssistant -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" ENABLE_CODE_COVERAGE=YES

# 4. Build de release
./scripts/build-release.sh

# 5. Verificar DMG
test -f "MeetingAssistant-x.x.x.dmg" && echo "DMG criado com sucesso"
```

**Checklist Final**:
- [ ] 0 errors no lint
- [ ] 0 warnings no lint (ideal) ou < 10
- [ ] 22/22 testes passando
- [ ] Cobertura > 55%
- [ ] DMG criado com sucesso
- [ ] Nenhum código de debug em produção

---

## Matriz de Dependências

```
Fase 0 (Prep)
    │
    ▼
Fase 1 (Críticas) ──────┬───► Fase 2 (Qualidade)
    │                   │
    │                   ▼
    │           Fase 3 (Testes) ──► Fase 4 (Doc)
    │                   │
    │                   ▼
    │           Fase 5 (Habilidades)
    │                   │
    └───────────────────┘
                        ▼
              Fase 6 (Validação Final)
```

---

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Regressões em código | Média | Alto | Testes automatizados, code review |
| Quebras de API | Baixa | Alto | Testes de integração |
| Tempo excedente | Alta | Médio | Focar em prioridades, adiar nice-to-have |
| Conflitos de merge | Média | Médio | Branch dedicado, PRs pequenos |

---

## Recursos Necessários

### Ferramentas
- SwiftLint (instalado)
- SwiftFormat (instalado)
- XcodeGen (instalado)
- Xcode Command Line Tools

### Tempo Estimado Total
- Fase 1-5: ~20 dias (trabalho parcial)
- Fase 6: 1 dia

### Responsabilidades
| Fase | Responsável |
|------|-------------|
| 1-2 | Desenvolvedor Senior |
| 3-4 | QA/Dev |
| 5 | Arquiteto |

---

## Próximos Passos Imediatos

1. **Agora**: Criar branch `improvement-analysis-$(date +%Y%m%d)`
2. **Em 5 minutos**: Corrigir empty_count error (ação 1.1)
3. **Em 30 minutos**: Corrigir testes de localização (ação 1.2)
4. **Hoje**: Validar que todos os testes passam

---

## Referências

| Documento | Descrição |
|-----------|-----------|
| [PLANO_FASE1_DOCUMENTACAO.md](PLANO_FASE1_DOCUMENTACAO.md) | Detalhes da Fase 1 |
| [PLANO_FASE2_REGRAS_HABILIDADES.md](PLANO_FASE2_REGRAS_HABILIDADES.md) | Detalhes da Fase 2 |
| [PLANO_FASE3_ARQUITETURA.md](PLANO_FASE3_ARQUITETURA.md) | Detalhes da Fase 3 |
| [PLANO_FASE4_QUALIDADE_TESTES.md](PLANO_FASE4_QUALIDADE_TESTES.md) | Detalhes da Fase 4 |
| [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) | Limitações conhecidas |
| [AGENTS.md](AGENTS.md) | Guia para agentes |
