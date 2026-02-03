# Dependencies Audit (Issue #37)

Data: 2026-02-03  
Branch: `codex/issue-37-deps-audit`  
Escopo: **todas** as dependências (runtime, testes, tooling local, CI/CD e scripts).

## Fontes analisadas

- SwiftPM:
  - `Packages/MeetingAssistantCore/Package.swift` (dependências diretas)
  - `Packages/MeetingAssistantCore/Package.resolved` (pins de topo)
  - `Packages/MeetingAssistantCore/.build/workspace-state.json` + `Packages/MeetingAssistantCore/.build/checkouts/` (checkouts presentes no workspace local)
- Projeto/Build:
  - `MeetingAssistant.xcodeproj/project.pbxproj`
  - `Makefile`
  - `scripts/*`
- CI/CD:
  - `.github/workflows/ci.yml`
  - `.github/workflows/release.yml`
  - `.github/workflows/generate-docs.yml`

> Observação: `Package.resolved` **não lista transitivas**. Para transitivas/checkouts, usei o `workspace-state.json` quando disponível — ele pode ficar **stale** (ex.: checkouts antigos em `.build`). A fonte de verdade para “o que o projeto declara” é o `Package.swift`.

---

## Lista por categoria

### Usadas

#### SwiftPM (diretas)

- **FluidAudio** (`0.10.0`) — runtime (core feature)
  - Evidência: `@preconcurrency import FluidAudio` em `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/FluidAudioProvider.swift` e `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/FluidAIModelManager.swift`.
- **KeyboardShortcuts** (`2.4.0`) — runtime (atalhos globais)
  - Evidência: `import KeyboardShortcuts` em `App/GlobalShortcutController.swift`, `App/AssistantShortcutController.swift` e uso no Core (settings).
- **swift-atomics** (`1.3.0`) — runtime (concorrência/estado em pipeline de áudio)
  - Evidência: `import Atomics` + `ManagedAtomic` em `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/SystemAudioRecorder.swift`, `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecordingWorker.swift`, `Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioRecorder.swift`.
- **swift-syntax** (`602.0.0`) — build-time (Swift Macros para mocks)
  - Evidência: target macro `MeetingAssistantCoreMockingMacros` em `Packages/MeetingAssistantCore/Package.swift`.

#### SwiftPM (checkouts/transitivas presentes no workspace)

> Abaixo estão dependências que aparecem em `.build` como checkouts. Elas podem entrar indiretamente via SwiftPM **ou** podem ser resíduos de resoluções anteriores (stale).

- AEXML (`4.7.0`)
- FileKit (`6.1.0`)
- PathKit (`1.0.1`)
- Rainbow (`4.2.1`)
- Spectre (`0.10.1`)
- Stencil (`0.15.1`)
- TOMLKit (`0.6.0`)
- XcodeProj (`9.7.2`)
- swift-argument-parser (`1.7.0`)

#### Tooling local / scripts

- **SwiftFormat** — formatação
  - Evidência: `Makefile` roda `swiftformat` no target `format` (pré-requisito de `make build`).
  - Evidência: `scripts/lint.sh`, `scripts/lint-fix.sh` e `scripts/hooks/pre-commit`.
- **SwiftLint** — lint
  - Evidência: `Makefile` (`make lint`) e `scripts/lint.sh`, `scripts/lint-fix.sh`, `scripts/code-health-check.sh`, `scripts/hooks/pre-commit`.
- **PR heuristics (script)** — checagens leves em PR (warnings)
  - Evidência: `scripts/pr-checks.sh`.
- Ferramentas Apple (ambiente)
  - `xcodebuild`, `codesign`, `hdiutil` (usadas por `Makefile`/scripts e workflows).

#### CI/CD (GitHub Actions)

- Workflow CI (`.github/workflows/ci.yml`)
  - **Lint job**: instala `swiftlint`/`swiftformat` e roda `STRICT_LINT=1 make lint`.
  - **Test job**: roda `make ci-test`.
- Workflow Release (`.github/workflows/release.yml`)
  - build release + create dmg + upload artifact + gh-release.

---

### Não usadas (candidatas fortes)

- **Cuckoo** (test-only) — **removido** do projeto nesta branch.
  - Remoções aplicadas: dependência no `Package.swift`, mocks gerados, configs (`Cuckoofile.*`) e target `make mocks`.
  - Observação: checkouts antigos ainda podem aparecer em `Packages/MeetingAssistantCore/.build/` até um `swift package reset` (ou limpeza da pasta `.build`).

---

### Subutilizadas (avaliar caso a caso)

> Candidatas com potencial de remoção, mas exigem decisão de produto/processo. Recomenda-se ser conservador: **não remover sem alternativa clara + validação**.

- **swift-syntax**
  - Uso atual: exclusivamente para suportar Swift Macros (mocks) no Core.
  - Trade-off: removeu o Cuckoo (e tooling), mas adiciona um pacote grande ao grafo de build.
  - Direção sugerida: manter enquanto a estratégia de mocks via macros for padrão; revisitar se quisermos tornar mocking **test-only** (isolando o uso de `@GenerateMock` para fora do target principal ou adotando outra abordagem).

- **swift-atomics**
  - Uso atual: flags/contadores simples (`ManagedAtomic<Bool>`, `ManagedAtomic<UInt32>`), mas em hot paths de áudio.
  - Direção sugerida: manter por enquanto; revisitar quando houver janela para testes de estresse/TSan.

---

## Recomendações e impactos (alinhadas com sua ordem)

### Fase 1 — Higiene imediata (quick wins)

1) **Limpeza do workflow de release** (remover install de lint/format)
- Implementado: removi `brew install swiftlint swiftformat` de `.github/workflows/release.yml`.
- Impacto: job de release mais rápido e com menos variabilidade.

2) **Decisão sobre XcodeGen** (assumir `.xcodeproj` como fonte de verdade)
- Implementado: removi `project.yml` e referências a XcodeGen.
- Impacto: menos ambiguidade; risco de drift manual do `.xcodeproj` (mitigado por revisão/CI).

### Fase 2 — Redução de custo de CI & build

3) **Aposentar Danger-Swift**
- Implementado: removi `Dangerfile.swift`, os targets do `Makefile` e o job do Danger no CI.
- Substituição: lint/format como gate (`STRICT_LINT=1 make lint`) + `scripts/pr-checks.sh` emitindo warnings.
- Impacto: menos setup no CI; gate objetivo sem ficar excessivamente restritivo.

### Fase 3 — Refatoração estrutural (longo prazo)

4) **Estratégia de testes (substituição do Cuckoo)**
- Implementado: mocks via Swift Macros (`@GenerateMock`) + migração dos testes que dependiam de Cuckoo.
- Removido: Cuckoo, mocks gerados e tooling/configs.
- Impacto: reduz tooling de mocks e facilita evolução incremental dos testes; custo é uma dependência de build (`swift-syntax`).

5) **Manutenção da concorrência**
- Sugestão: manter `swift-atomics` por enquanto.
- Impacto: evita risco em pipeline de áudio; revisitar com janela para testes de estresse/TSan.
