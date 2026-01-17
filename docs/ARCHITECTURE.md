# Project Architecture

> **Última Atualização:** 2026-01-17
> **Tags:** #Architecture, #MVVM, #Audio, #Infrastructure

## 1. Visão Geral (Overview)
O projeto segue uma arquitetura em camadas focada em modularidade, testabilidade e separação de responsabilidades. Adotamos **MVVM (Model-View-ViewModel)** na camada de apresentação e **Clean Architecture** simplificada para serviços e dados.

## 2. Camadas Principais

### Infrastructure Layer
Camada responsável pela comunicação com o mundo externo e persistência.
- **Storage Service**: Abstração baseada em protocolos para persistência de dados. Permite trocar a implementação (CoreData, FileManager, InMemory) sem afetar a lógica de negócio.
- **External Integrations**: Serviços que se comunicam com APIs ou recursos do sistema operacional ficam isolados aqui.

### Domain/Core Layer
Contém as regras de negócio e modelos fundamentais.
- **MeetingAssistantCore**: Framework central que encapsula a lógica de gravação, transcrição e gerenciamento de reuniões.

### Presentation Layer
- **ViewModels**: Responsáveis pelo estado da View. Não devem importar UIKit/AppKit diretamente se possível.
- **Views**: SwiftUI ou AppKit views que reagem ao estado do ViewModel. Dependem de protocolos, não de implementações concretas.

---

## 3. Audio Subsystem Architecture

O sistema de gravação é projetado para alta performance e baixa latência, capturando tanto Microfone quanto Áudio do Sistema (ScreenCaptureKit).

### Key Components

#### 1. SystemAudioRecorder (Producer)
- **Role**: Captures system audio via `ScreenCaptureKit`.
- **Concurrency**: Operates on a dedicated background queue (`userInitiated`).
- **Optimization**: Uses a `nonisolated` callback property (`onAudioBuffer`) to push buffers directly to the consumer without hopping to the Main Actor.
- **Safety**: `CallbackStorage` is protected by `OSAllocatedUnfairLock` to ensure thread-safe updates to the callback closure.

#### 2. AudioBufferQueue (Bridge)
- **Role**: Thread-safe FIFO bridge between the Push-based producer (SCK) and Pull-based consumer (AVAudioEngine).
- **Structure**: Fixed-size Circular Buffer (Ring Buffer).
- **Concurrency**: Uses `OSAllocatedUnfairLock` (Spinlock equivalent) for extremely low overhead blocking (nanoseconds).
- **Allocation**: Pre-allocates storage to ensure **Zero Allocations** during the steady-state recording loop.

#### 3. AudioRecorder (Consumer/Mixer)
- **Role**: Manages the `AVAudioEngine` graph.
- **Components**:
    - `AVAudioSourceNode`: Pulls data from `AudioBufferQueue`.
    - `AVAudioMixerNode`: Merges Mic and System audio.
- **Optimization**: Uses `memcpy` (via `UnsafeMutableBufferPointer`) for audio buffer copying instead of naive loops, reducing CPU usage during the high-frequency render callback (Hot Path).

#### 4. AudioRecordingWorker (Writer)
- **Role**: Handles file writing and metering.
- **Pattern**: **Worker Pattern** (Extracted from `AudioRecorder`).
- **Concurrency**: Implemented as a Swift **Actor** for automatic thread safety and state isolation.
- **Optimization**: Processes buffers non-isolatedly when possible to minimize actor contention.

### Memory & Performance Policy
- **Cycle Prevention**: All coordinators and long-lived services must use `[weak self]` in closures.
- **Zero Allocation**: The audio hot path (Producer to Consumer) must favor pre-allocated buffers and avoid heap allocations during active recording.
- **Locking**: `NSLock` is forbidden in the real-time audio thread (`AudioSourceNode`). `OSAllocatedUnfairLock` is the only permitted synchronization primitive there.
- **Main Actor Isolation**: The audio hot path (callbacks) MUST NOT touch the Main Actor.

## 4. Referências Cruzadas
- `.agent/rules/testing.md`
- `.agent/rules/architecture.md`
- `.agent/skills/audio-realtime/SKILL.md`
- `.agent/skills/quality-assurance/SKILL.md`

