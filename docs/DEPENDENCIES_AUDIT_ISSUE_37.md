# Dependencies Audit (Issue #37)

Data: 2026-02-03  
Branch: `codex/issue-37-deps-audit`  
Escopo: **todas** as dependências (runtime, testes, tooling local, CI/CD e scripts).

## Fontes analisadas

- SwiftPM:
  - `Packages/MeetingAssistantCore/Package.swift` (dependências diretas)
  - `Packages/MeetingAssistantCore/.build/workspace-state.json` + `Packages/MeetingAssistantCore/.build/checkouts/` (dependências resolvidas/transitivas existentes no workspace local)
- Projeto/Build:
  - `MeetingAssistant.xcodeproj/project.pbxproj`
  - `Makefile`
  - `scripts/*`
- CI/CD:
  - `.github/workflows/ci.yml`
  - `.github/workflows/release.yml`
  - `.github/workflows/generate-docs.yml`

> Observação: o repositório não contém `Package.resolved` no root nem dentro de `Packages/MeetingAssistantCore/`.
> Para este relatório, a lista “resolvida/transitiva” foi extraída do `workspace-state.json` presente em `.build` (quando existente).

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
- **Cuckoo** (`2.2.0`) — **test-only** (mocks)
  - Evidência: `import Cuckoo` em `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/*` e alvo `testTarget` em `Packages/MeetingAssistantCore/Package.swift`.

#### SwiftPM (resolvidas/transitivas no workspace)

> Essas dependências entram **indiretamente** via SwiftPM (por dependência de dependências). Não há “import” no app/core necessariamente, mas são necessárias enquanto a dependência “pai” existir.

- AEXML (`4.7.0`)
- FileKit (`6.1.0`)
- PathKit (`1.0.1`)
- Rainbow (`4.2.1`)
- Spectre (`0.10.1`)
- Stencil (`0.15.1`)
- TOMLKit (`0.6.0`)
- XcodeProj (`9.7.2`)
- swift-argument-parser (`1.7.0`)
- swift-syntax (`602.0.0`)

#### Tooling local / scripts

- **SwiftFormat** — formatação
  - Evidência: `Makefile` roda `swiftformat` no target `format` (pré-requisito de `make build`).
  - Evidência: `scripts/lint.sh`, `scripts/lint-fix.sh` e `scripts/hooks/pre-commit`.
- **SwiftLint** — lint
  - Evidência: `Makefile` (`make lint`) e `scripts/lint.sh`, `scripts/lint-fix.sh`, `scripts/code-health-check.sh`, `scripts/hooks/pre-commit`.
- **PR heuristics (script)** — checagens leves em PR (warnings)
  - Evidência: `scripts/pr-checks.sh` (substitui as regras do antigo Dangerfile).
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

- No estado atual, **nenhuma dependência SwiftPM direta** aparece como “declarada e não usada”.

---

### Subutilizadas (avaliar caso a caso)

> Abaixo são candidatas com potencial de remoção, mas exigem decisão de produto/processo. A recomendação é conservadora: **não remover sem alternativa clara + validação**.

- **Cuckoo (test-only)**
  - Sinal: grande árvore de transitivas (Stencil, PathKit, XcodeProj, swift-syntax, etc.) para dar suporte a geração/mocks.
  - Direção sugerida (longo prazo): POC com Swift Macros para mocking e adoção progressiva.

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
- Implementado: removi `project.yml` e referências a XcodeGen (Makefile/README/scripts/AGENTS).
- Impacto: menos ambiguidade para novos devs; risco é drift manual do `.xcodeproj` (mitigado por revisão/CI).

### Fase 2 — Redução de custo de CI & build

3) **Aposentar Danger-Swift**
- Implementado: removi `Dangerfile.swift`, os targets do `Makefile` e o job do Danger no CI.
- Substituição: lint/format como gate (`STRICT_LINT=1 make lint`) + `scripts/pr-checks.sh` emitindo warnings (PR grande, sem testes, prints, TODO/FIXME, force unwrap, doc pública).
- Impacto: reduz dependência de Homebrew + Danger, mantendo o “bom senso” via warnings e um gate objetivo via lint.

### Fase 3 — Refatoração estrutural (longo prazo)

4) **Estratégia de testes (substituição do Cuckoo)**
- Implementado (POC): adicionados os targets `MeetingAssistantCoreMocking`/`MeetingAssistantCoreMockingMacros` e um teste exemplo (`StartRecordingUseCaseMacroMockingTests`).
- Nota: essa POC adiciona `swift-syntax` como dependência direta; `Cuckoo` permanece por enquanto (migração progressiva, sem reescrever testes antigos).

5) **Manutenção da concorrência**
- Sugestão: manter `swift-atomics` por enquanto.
- Impacto: evita risco em pipeline de áudio; revisitar quando houver janela para testes de estresse/TSan e/ou mudanças de arquitetura.
