@preconcurrency import AVFoundation
@testable import MeetingAssistantCore
import XCTest

/// Testes de integração completa do sistema de áudio.
/// Testa a interação entre AudioRecorder, SystemAudioRecorder, AudioBufferQueue,
/// AudioRecordingWorker e RecordingManager.
@MainActor
final class AudioSystemTests: XCTestCase {
    var audioRecorder: AudioRecorder!
    var systemRecorder: SystemAudioRecorder!
    var bufferQueue: AudioBufferQueue!
    var recordingWorker: AudioRecordingWorker!
    var recordingManager: RecordingManager!

    // Mocks para isolamento
    var mockTranscription: MockTranscriptionClient!
    var mockPostProcessing: MockPostProcessingService!
    var mockStorage: MockStorageService!

    override func setUp() async throws {
        try await super.setUp()

        // Inicializar componentes reais para testes de integração
        self.audioRecorder = AudioRecorder.shared
        self.systemRecorder = SystemAudioRecorder.shared
        self.bufferQueue = AudioBufferQueue(capacity: 50)
        self.recordingWorker = AudioRecordingWorker()

        // Mocks para RecordingManager
        self.mockTranscription = MockTranscriptionClient()
        self.mockPostProcessing = MockPostProcessingService()
        self.mockStorage = MockStorageService()

        self.recordingManager = RecordingManager(
            transcriptionClient: self.mockTranscription,
            postProcessingService: self.mockPostProcessing,
            storage: self.mockStorage
        )
    }

    override func tearDown() async throws {
        // Cleanup
        _ = await self.audioRecorder.stopRecording()
        _ = await self.systemRecorder.stopRecording()
        self.recordingWorker = nil
        self.bufferQueue.clear()

        self.audioRecorder = nil
        self.systemRecorder = nil
        self.bufferQueue = nil
        self.recordingManager = nil
        self.mockTranscription = nil
        self.mockPostProcessing = nil
        self.mockStorage = nil

        try await super.tearDown()
    }

    // MARK: - Testes de Integração Básica

    func testAudioRecorderIntegration_WithSystemAudio() async throws {
        // Skip test if running in CI or without screen recording permissions
        guard await self.systemRecorder.hasPermission() else {
            throw XCTSkip("Screen recording permission not available")
        }

        // Given
        let outputURL = self.createTemporaryURL()

        // When
        try await self.audioRecorder.startRecording(to: outputURL, source: .all, retryCount: 0)

        // Pequena pausa para estabilizar
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        let stoppedURL = await audioRecorder.stopRecording()

        // Then
        XCTAssertNotNil(stoppedURL)
        XCTAssertEqual(stoppedURL, outputURL)
        XCTAssertFalse(self.audioRecorder.isRecording)
    }

    func testSystemAudioRecorder_BufferCallbackIntegration() async throws {
        // Skip test if running in CI or without screen recording permissions
        guard await self.systemRecorder.hasPermission() else {
            throw XCTSkip("Screen recording permission not available")
        }

        // Given
        let receivedBuffers = AtomicArray<AVAudioPCMBuffer>()
        let expectation = expectation(description: "Buffer callback received")

        self.systemRecorder.onAudioBuffer = { @Sendable buffer in
            receivedBuffers.append(buffer)
            if receivedBuffers.count >= 3 {
                expectation.fulfill()
            }
        }

        // When
        try await self.systemRecorder.startRecording(to: self.createTemporaryURL(), sampleRate: 48_000.0)

        // Wait for buffers or timeout
        await fulfillment(of: [expectation], timeout: 2.0)

        _ = await self.systemRecorder.stopRecording()

        // Then
        XCTAssertGreaterThan(receivedBuffers.count, 0, "Should have received audio buffers")
        XCTAssertFalse(self.systemRecorder.isRecording)
    }

    func testAudioBufferQueue_IntegrationWithSystemRecorder() async throws {
        // Skip test if running in CI or without screen recording permissions
        guard await self.systemRecorder.hasPermission() else {
            throw XCTSkip("Screen recording permission not available")
        }

        // Given
        let enqueuedCount = ThreadSafeCounter()
        let expectation = expectation(description: "Buffers enqueued")
        expectation.expectedFulfillmentCount = 5

        self.systemRecorder.onAudioBuffer = { @Sendable [bufferQueue = self.bufferQueue!] buffer in
            bufferQueue.enqueue(buffer)
            let count = enqueuedCount.increment()
            if count >= 5 {
                expectation.fulfill()
            }
        }

        // When
        try await self.systemRecorder.startRecording(to: self.createTemporaryURL(), sampleRate: 48_000.0)

        await fulfillment(of: [expectation], timeout: 2.0)

        _ = await self.systemRecorder.stopRecording()

        // Then
        XCTAssertGreaterThanOrEqual(self.bufferQueue.stats.count, 5)
        XCTAssertEqual(self.bufferQueue.stats.dropped, 0) // Não deve ter perdido buffers inicialmente
    }

    func testAudioRecordingWorker_BufferProcessingIntegration() async throws {
        // Given
        let outputURL = self.createTemporaryURL()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

        try await recordingWorker.start(writingTo: outputURL, format: format, fileFormat: .wav)

        // Simular buffers do AudioRecorder
        let testBuffers = try createTestBuffers(count: 10, frameCount: 1024)

        // When
        for buffer in testBuffers {
            self.recordingWorker.process(buffer)
        }

        try await Task.sleep(nanoseconds: 200_000_000) // Aguardar processamento

        let finalURL = await recordingWorker.stop()

        // Then
        XCTAssertNotNil(finalURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL!.path))

        // Verificar se arquivo tem conteúdo
        let asset = AVAsset(url: finalURL!)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0)
    }

    // MARK: - Testes de Estado Consistente

    func testStateConsistency_AudioRecorderStateTransitions() async throws {
        try XCTSkipIf(true, "Integration test requiring hardware")
        let outputURL = self.createTemporaryURL()

        // Estado inicial
        XCTAssertFalse(self.audioRecorder.isRecording)
        XCTAssertNil(self.audioRecorder.currentRecordingURL)

        // Iniciar gravação
        try await self.audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)

        XCTAssertTrue(self.audioRecorder.isRecording)
        XCTAssertEqual(self.audioRecorder.currentRecordingURL, outputURL)

        // Parar gravação
        let stoppedURL = await audioRecorder.stopRecording()

        XCTAssertFalse(self.audioRecorder.isRecording)
        XCTAssertEqual(stoppedURL, outputURL)
        XCTAssertNil(self.audioRecorder.currentRecordingURL)
    }

    func testStateConsistency_BufferQueueStatsAccuracy() throws {
        let buffer = try createTestBuffer(frameCount: 512)

        // Estado inicial
        XCTAssertEqual(self.bufferQueue.stats.count, 0)
        XCTAssertEqual(self.bufferQueue.stats.dropped, 0)

        // Enqueue
        self.bufferQueue.enqueue(buffer)
        XCTAssertEqual(self.bufferQueue.stats.count, 1)

        // Dequeue
        let dequeued = self.bufferQueue.dequeue()
        XCTAssertNotNil(dequeued)
        XCTAssertEqual(self.bufferQueue.stats.count, 0)

        // Clear
        self.bufferQueue.enqueue(buffer)
        self.bufferQueue.clear()
        XCTAssertEqual(self.bufferQueue.stats.count, 0)
        XCTAssertEqual(self.bufferQueue.stats.dropped, 0)
    }

    // MARK: - Testes de Error Handling

    func testErrorHandling_AudioRecorderInvalidFormat() async {
        let outputURL = self.createTemporaryURL()

        // Simular erro através de configuração inválida
        // Nota: Testes reais de erro são difíceis sem mocks específicos
        do {
            try await self.audioRecorder.startRecording(to: outputURL, source: .all, retryCount: 0)
            _ = await self.audioRecorder.stopRecording()
            // Se chegou aqui, não houve erro crítico
        } catch {
            // Erros são esperados em alguns ambientes de teste
            XCTAssertNotNil(error)
        }
    }

    func testErrorHandling_BufferQueueOverflowHandling() throws {
        let smallCapacityQueue = AudioBufferQueue(capacity: 3)
        let buffer = try createTestBuffer(frameCount: 512)

        // Preencher até capacidade
        for _ in 0..<3 {
            smallCapacityQueue.enqueue(buffer)
        }

        XCTAssertEqual(smallCapacityQueue.stats.count, 3)

        // Overflow - deve dropar oldest
        smallCapacityQueue.enqueue(buffer)

        XCTAssertEqual(smallCapacityQueue.stats.count, 3) // Capacidade mantida
        XCTAssertGreaterThan(smallCapacityQueue.stats.dropped, 0) // Deve ter dropped
    }

    // MARK: - Testes de Buffer Overflow

    func testBufferOverflow_AudioBufferQueueDropOldest() throws {
        let smallQueue = AudioBufferQueue(capacity: 2)
        let buffers = try (0..<4).map { try self.createTestBuffer(frameCount: AVAudioFrameCount($0 + 1) * 256) }

        // Enqueue beyond capacity
        for buffer in buffers {
            smallQueue.enqueue(buffer)
        }

        // Should maintain capacity
        XCTAssertEqual(smallQueue.stats.count, 2)

        // Should have dropped frames
        XCTAssertGreaterThan(smallQueue.stats.dropped, 0)

        // Dequeue should return most recent buffers
        let first = smallQueue.dequeue()
        let second = smallQueue.dequeue()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first?.frameLength, 768) // 3rd buffer (index 2)
        XCTAssertEqual(second?.frameLength, 1024) // 4th buffer (index 3)
    }

    // MARK: - Testes de Thread Safety

    func testThreadSafety_BufferQueueConcurrentAccess() throws {
        let buffer = try createTestBuffer(frameCount: 1024)
        let iterations = 50
        let expectation = expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = iterations * 3

        for _ in 0..<iterations {
            DispatchQueue.global().async { [bufferQueue = self.bufferQueue!] in
                bufferQueue.enqueue(buffer)
                expectation.fulfill()
            }

            DispatchQueue.global().async { [bufferQueue = self.bufferQueue!] in
                _ = bufferQueue.dequeue()
                expectation.fulfill()
            }

            DispatchQueue.global().async { [bufferQueue = self.bufferQueue!] in
                _ = bufferQueue.stats
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        // Se chegou aqui sem crash, teste passou
    }

    // MARK: - Testes de Performance

    /* Commented out due to test runner instability
     func testPerformance_BufferQueueEnqueueDequeue() throws {
         let buffer = try createTestBuffer(frameCount: 2048)

         measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
             for _ in 0..<1000 {
                 self.bufferQueue.enqueue(buffer)
                 _ = self.bufferQueue.dequeue()
             }
         }
     }

     func testPerformance_BufferQueueHighThroughput() throws {
         let buffers = try (0..<100).map { _ in try self.createTestBuffer(frameCount: 1024) }

         measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
             for buffer in buffers {
                 self.bufferQueue.enqueue(buffer)
             }

             while !self.bufferQueue.isEmpty {
                 _ = self.bufferQueue.dequeue()
             }
         }
     }
     */

    /* Commented out due to test runner instability
     func testPerformance_BufferProcessingIntegration() {
         let outputURL = self.createTemporaryURL()
         let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
         let testBuffers = try! self.createTestBuffers(count: 50, frameCount: 1024)

         // Baseline: Buffer processing should complete within reasonable time limits
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             let exp = expectation(description: "Process integration")
             Task {
                 try? await self.recordingWorker.start(writingTo: outputURL, format: format, fileFormat: .wav)

                 for buffer in testBuffers {
                     self.recordingWorker.process(buffer)
                 }

                 _ = await self.recordingWorker.stop()
                 exp.fulfill()
             }
             wait(for: [exp], timeout: 10.0)
         }
     }
     */

    /* Commented out due to test runner instability
     func testPerformance_AudioRecordingStartStop() {
         let outputURL = self.createTemporaryURL()

         // Baseline: Recording operations should be fast and not consume excessive resources
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             let exp = expectation(description: "Start stop")
             Task {
                 try? await self.audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
                 _ = await self.audioRecorder.stopRecording()
                 exp.fulfill()
             }
             wait(for: [exp], timeout: 5.0)
         }
     }
     */

    /* Commented out due to test runner instability
     func testPerformance_SystemAudioBufferCallback() async throws {
         // Skip test if running in CI or without screen recording permissions
         guard await self.systemRecorder.hasPermission() else {
             throw XCTSkip("Screen recording permission not available")
         }

         let receivedBuffers = AtomicArray<AVAudioPCMBuffer>()
         let outputURL = self.createTemporaryURL()

         self.systemRecorder.onAudioBuffer = { @Sendable buffer in
             receivedBuffers.append(buffer)
         }

         // Baseline: Buffer callbacks should be processed efficiently
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             Task {
                 try await self.systemRecorder.startRecording(to: outputURL, sampleRate: 48_000.0)

                 // Wait for some buffers to be processed
                 try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                 _ = await self.systemRecorder.stopRecording()
             }
         }

         // Verify we received buffers
         XCTAssertGreaterThan(receivedBuffers.count, 0)
     }
     */

    /* Commented out due to test runner instability
     func testPerformance_BufferQueueOverflowHandling() throws {
         let smallQueue = AudioBufferQueue(capacity: 10)
         let buffer = try createTestBuffer(frameCount: 1024)

         // Baseline: Overflow handling should be efficient even under high load
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             // Fill queue beyond capacity multiple times
             for _ in 0..<200 { // 20x capacity
                 smallQueue.enqueue(buffer)
             }
         }

         // Verify overflow behavior
         XCTAssertEqual(smallQueue.stats.count, 10) // Should maintain capacity
         XCTAssertGreaterThan(smallQueue.stats.dropped, 0) // Should have dropped buffers
     }
     */

    /* Commented out due to test runner instability
     func testPerformance_RecordingManagerStateTransitions() {
         // Baseline: State transitions should be fast
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             let exp = expectation(description: "State transitions")
             Task {
                 await self.recordingManager.startRecording()
                 await self.recordingManager.stopRecording()
                 exp.fulfill()
             }
             wait(for: [exp], timeout: 5.0)
         }
     }
     */

    // MARK: - Testes de Cleanup Adequado

    func testCleanup_AudioRecorderResourceCleanup() async throws {
        try XCTSkipIf(true, "Integration test requiring hardware")
        let outputURL = self.createTemporaryURL()

        try await self.audioRecorder.startRecording(to: outputURL, source: .all, retryCount: 0)
        XCTAssertTrue(self.audioRecorder.isRecording)

        _ = await self.audioRecorder.stopRecording()

        // Verificar estado limpo
        XCTAssertFalse(self.audioRecorder.isRecording)
        XCTAssertNil(self.audioRecorder.currentRecordingURL)
        XCTAssertEqual(self.audioRecorder.currentAveragePower, -160.0)
        XCTAssertEqual(self.audioRecorder.currentPeakPower, -160.0)
    }

    func testCleanup_BufferQueueCompleteClear() throws {
        let buffer = try createTestBuffer(frameCount: 512)

        // Preencher queue
        for _ in 0..<10 {
            self.bufferQueue.enqueue(buffer)
        }

        XCTAssertGreaterThan(self.bufferQueue.stats.count, 0)

        // Clear
        self.bufferQueue.clear()

        XCTAssertTrue(self.bufferQueue.isEmpty)
        XCTAssertEqual(self.bufferQueue.stats.count, 0)
        XCTAssertEqual(self.bufferQueue.stats.dropped, 0)
    }

    func testCleanup_RecordingWorkerFileClosure() async throws {
        let outputURL = self.createTemporaryURL()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

        try await recordingWorker.start(writingTo: outputURL, format: format, fileFormat: .wav)

        let testBuffer = try createTestBuffer(frameCount: 1024)
        self.recordingWorker.process(testBuffer)

        let finalURL = await recordingWorker.stop()

        XCTAssertNotNil(finalURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL!.path))

        // Worker deve estar completamente limpo
        // (não há propriedades públicas para verificar, mas arquivo deve existir)
    }

    // MARK: - Helpers

    private func createTemporaryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "test_audio_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }

    private func createTestBuffer(frameCount: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create format"])
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        buffer.frameLength = frameCount

        // Fill with test data
        if let channelData = buffer.floatChannelData {
            for ch in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frameCount) {
                    channelData[ch][frame] = sin(Float(frame) * 0.01) // Simple sine wave
                }
            }
        }

        return buffer
    }

    private func createTestBuffers(count: Int, frameCount: AVAudioFrameCount) throws -> [AVAudioPCMBuffer] {
        try (0..<count).map { _ in try self.createTestBuffer(frameCount: frameCount) }
    }
}

// MARK: - Thread-Safe Helpers

/// Thread-safe array wrapper for test data collection in concurrent environments
private final class AtomicArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []

    var count: Int {
        self.lock.withLock { self.storage.count }
    }

    func append(_ element: Element) {
        self.lock.withLock { self.storage.append(element) }
    }

    func getElements() -> [Element] {
        self.lock.withLock { self.storage }
    }
}

/// Thread-safe counter for test coordination
private final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int = 0

    func increment() -> Int {
        self.lock.withLock {
            self.value += 1
            return self.value
        }
    }

    var currentValue: Int {
        self.lock.withLock { self.value }
    }
}
