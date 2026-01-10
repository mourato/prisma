# Áudio Real-Time

> **Skill Condicional** - Ativada quando trabalhando com código de áudio

## Visão Geral

Esta skill aborda políticas críticas para processamento de áudio em tempo real, onde alocações de memória e locks são especialmente sensíveis.

## Quando Usar

Ative esta skill quando detectar:
- `AVAudioSourceNode`
- `AVAudioEngine` + `installTap`
- `ProcessTap`
- `AudioRecorder`
- `SystemAudioRecorder`
- `AudioBufferQueue`

## Conceitos-Chave

### Zero Allocation Policy

**CRÍTICO**: NUNCA aloque memória dentro de callbacks de áudio.

```swift
// ❌ ERRADO - Aloca memória no callback
func renderBlock(timestamp: AVAudioTime, frameCount: AVAudioFrameCount) -> UnsafePointer<Float> {
    let buffer = [Float](repeating: 0, count: Int(frameCount)) // ALOCA!
    return process(buffer)
}

// ✅ CORRETO - Use ring buffer pré-alocado
class AudioProcessor {
    private let ringBuffer: RingBuffer // Alocado uma vez na init

    func renderBlock(timestamp: AVAudioTime, frameCount: AVAudioFrameCount) {
        guard let output = ringBuffer.readBuffer(count: Int(frameCount)) else { return }
        processSamples(output)
    }
}
```

### Ring Buffer Pré-Alocado

```swift
final class RingBuffer {
    private let capacity: Int
    private let buffer: UnsafeMutablePointer<Float>
    private var writeIndex = 0
    private var readIndex = 0

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
    }

    deinit {
        buffer.deallocate()
    }

    func write(_ data: UnsafePointer<Float>, count: Int) {
        let copies = min(count, capacity)
        memcpy(buffer.advanced(by: writeIndex), data, copies * MemoryLayout<Float>.size)
        writeIndex = (writeIndex + copies) % capacity
    }

    func readBuffer(count: Int) -> UnsafeMutableBufferPointer<Float>? {
        guard count <= capacity else { return nil }
        return UnsafeMutableBufferPointer(start: buffer.advanced(by: readIndex), count: count)
    }
}
```

### Bounds Checking

Sempre use `min()` para prevenir buffer overflows:

```swift
// ✅ CORRETO
let copies = min(source.count, dest.count)
memcpy(destPtr, sourcePtr, copies * MemoryLayout<Element>.size)
```

### Lock Safety

**NUNCA use** `NSLock` ou `@MainActor` em callbacks de áudio real-time. Use `OSAllocatedUnfairLock`:

```swift
import os.lock

final class AtomicCounter {
    private let lock = OSAllocatedUnfairLock(initialState: 0)

    func increment() {
        lock.withLock { $0 += 1 }
    }

    var value: Int {
        lock.withLock { $0 }
    }
}
```

## Patterns Comuns

### Audio Buffer Queue

```swift
final class AudioBufferQueue {
    private let queue = DispatchQueue(label: "com.meeting.audio.buffer", qos: .userInitiated)
    private var buffers: [Data] = []

    // ❌ Não faça isso - aloca no callback
    func processAudio(_ data: UnsafePointer<Float>, frameCount: UInt32) {
        queue.async {
            let copy = Data(bytes: data, count: Int(frameCount) * MemoryLayout<Float>.size)
            self.buffers.append(copy)
        }
    }
}
```

## Armadilhas Comuns

1. **Strings em callbacks** - Mesmo `"\(value)"` aloca memória
2. **Arrays temporários** - `[Float](repeating:)` aloca
3. **Error creation** - `throw MyError()` pode alocar
4. **Getters complexos** - Evite computed properties em callbacks

## Referências

- [AudioBufferQueue.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/AudioBufferQueue.swift)
- [SystemAudioRecorder.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/SystemAudioRecorder.swift)
- [docs/ARCHITECTURE.md](../../../../docs/ARCHITECTURE.md)
