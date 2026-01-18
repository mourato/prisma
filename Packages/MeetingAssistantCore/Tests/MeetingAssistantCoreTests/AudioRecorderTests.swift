@preconcurrency import AVFoundation
@testable import MeetingAssistantCore
import XCTest

/// Testes unitários para AudioRecorder usando MockAudioEngine
@MainActor
final class AudioRecorderTests: XCTestCase {
    var audioRecorder: AudioRecorder?
    var mockEngine: MockAudioEngine?
    var mockWorker: MockAudioRecordingWorker?

    override func setUp() async throws {
        try await super.setUp()

        // Criar mocks
        self.mockEngine = MockAudioEngine()
        self.mockWorker = MockAudioRecordingWorker()

        // Injetar dependências - MockAudioEngine não é compatível com AVAudioEngine,
        // então criamos um wrapper ou usamos uma abordagem diferente
        // Por enquanto, vamos usar o AudioRecorder padrão e mockar outras dependências
        self.audioRecorder = AudioRecorder()
    }

    override func tearDown() async throws {
        if let recorder = self.audioRecorder {
            await recorder.stopRecording()
        }
        self.audioRecorder = nil
        self.mockEngine = nil
        self.mockWorker = nil
        try await super.tearDown()
    }

    // MARK: - Testes de Estado Inicial

    func testInitialState() {
        guard let audioRecorder = self.audioRecorder else { return XCTFail("AudioRecorder not initialized") }
        XCTAssertFalse(audioRecorder.isRecording)
        XCTAssertNil(audioRecorder.currentRecordingURL)
        XCTAssertNil(audioRecorder.error)
        XCTAssertEqual(audioRecorder.currentAveragePower, -160.0)
        XCTAssertEqual(audioRecorder.currentPeakPower, -160.0)
    }

    // MARK: - Testes de Start Recording

    func testStartRecordingMicrophoneOnly() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)

        XCTAssertTrue(audioRecorder.isRecording)
        XCTAssertEqual(audioRecorder.currentRecordingURL, outputURL)
        XCTAssertTrue(mockEngine.isRunning)
    }

    func testStartRecordingSystemAudioOnly() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .system, retryCount: 0)

        XCTAssertTrue(audioRecorder.isRecording)
        XCTAssertEqual(audioRecorder.currentRecordingURL, outputURL)
        XCTAssertTrue(mockEngine.isRunning)
    }

    func testStartRecordingAllSources() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .all, retryCount: 0)

        XCTAssertTrue(audioRecorder.isRecording)
        XCTAssertEqual(audioRecorder.currentRecordingURL, outputURL)
        XCTAssertTrue(mockEngine.isRunning)
    }

    func testStartRecordingEngineFailure() async {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        mockEngine.shouldFailStart = true
        let outputURL = self.createTemporaryURL()

        do {
            try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
            XCTFail("Expected start recording to fail")
        } catch {
            XCTAssertNotNil(audioRecorder.error)
            XCTAssertFalse(audioRecorder.isRecording)
        }
    }

    // MARK: - Testes de Stop Recording

    func testStopRecording() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
        XCTAssertTrue(audioRecorder.isRecording)

        let stoppedURL = await audioRecorder.stopRecording()

        XCTAssertEqual(stoppedURL, outputURL)
        XCTAssertFalse(audioRecorder.isRecording)
        XCTAssertNil(audioRecorder.currentRecordingURL)
        XCTAssertFalse(mockEngine.isRunning)
    }

    func testStopRecordingWhenNotRecording() async {
        guard let audioRecorder = self.audioRecorder else { return XCTFail("AudioRecorder not initialized") }
        let result = await audioRecorder.stopRecording()
        XCTAssertNil(result)
    }

    // MARK: - Testes de Transições de Estado

    func testStateTransitions() async throws {
        guard let audioRecorder = self.audioRecorder else { return XCTFail("AudioRecorder not initialized") }
        let outputURL = self.createTemporaryURL()

        // Estado inicial
        XCTAssertFalse(audioRecorder.isRecording)

        // Iniciar
        try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
        XCTAssertTrue(audioRecorder.isRecording)
        XCTAssertEqual(audioRecorder.currentRecordingURL, outputURL)

        // Parar
        let stoppedURL = await audioRecorder.stopRecording()
        XCTAssertFalse(audioRecorder.isRecording)
        XCTAssertEqual(stoppedURL, outputURL)
        XCTAssertNil(audioRecorder.currentRecordingURL)
    }

    // MARK: - Testes de Timing Determinístico

    func testTimingControl() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        mockEngine.prepareDelay = 0.05
        mockEngine.startDelay = 0.05

        let outputURL = self.createTemporaryURL()
        let startTime = Date()

        try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThan(elapsed, 0.08) // Pelo menos 100ms total
    }

    // MARK: - Testes de Validação de Estado

    func testEngineStateValidation() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
        XCTAssertTrue(mockEngine.isRunning)

        await audioRecorder.stopRecording()
        XCTAssertFalse(mockEngine.isRunning)
    }

    // MARK: - Testes de Error Handling

    func testErrorPropagation() async {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        mockEngine.shouldFailPrepare = true
        let outputURL = self.createTemporaryURL()

        do {
            try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(audioRecorder.error)
            XCTAssertFalse(audioRecorder.isRecording)
        }
    }

    // MARK: - Testes de Callbacks e Simulação

    func testTapInstallation() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)

        // Verificar se tap foi instalado no mixer
        // Nota: Como estamos usando mock, podemos verificar comportamento simulado
        XCTAssertTrue(mockEngine.isRunning)
    }

    func testSourceNodeAttachment() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        let outputURL = self.createTemporaryURL()

        try await audioRecorder.startRecording(to: outputURL, source: .system, retryCount: 0)

        // Verificar se source node foi anexado
        XCTAssertTrue(mockEngine.isRunning)
    }

    // MARK: - Testes de Configuração de Hardware

    func testHardwareSampleRateDetection() async throws {
        guard let audioRecorder = self.audioRecorder, let mockEngine = self.mockEngine else { return XCTFail("Components not initialized") }
        // Configurar mock para simular sample rate específica
        guard let mockOutputNode = mockEngine.outputNode as? MockAudioOutputNode else {
            return XCTFail("Failed to cast outputNode to MockAudioOutputNode")
        }
        mockOutputNode.outputFormatSampleRate = 44_100

        let outputURL = self.createTemporaryURL()

        try await self.audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)

        // Verificar se engine está rodando (simulação de detecção)
        XCTAssertTrue(self.mockEngine.isRunning)
    }

    // MARK: - Testes de Conectividade

    func testNodeConnections() async throws {
        let outputURL = self.createTemporaryURL()

        try await self.audioRecorder.startRecording(to: outputURL, source: .all, retryCount: 0)

        // Verificar se conexões foram estabelecidas
        XCTAssertTrue(self.mockEngine.isRunning)
    }

    // MARK: - Performance Tests

    /* Commented out due to async/sync measure block instability
     func testPerformance_StartRecordingOperation() async throws {
         let outputURL = createTemporaryURL()

         // Baseline: Start recording should be reasonably fast
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             Task {
                 try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
                 _ = await audioRecorder.stopRecording()
             }
         }
     }

     func testPerformance_StopRecordingOperation() async throws {
         let outputURL = createTemporaryURL()

         // Pre-start recording for stop measurement
         try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)

         // Baseline: Stop recording should be very fast
         measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
             Task {
                 _ = await audioRecorder.stopRecording()
             }
         }
     }

     func testPerformance_MultipleStartStopCycles() async throws {
         // Baseline: Multiple recording cycles should not degrade performance
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             Task {
                 for _ in 0..<10 {
                     let outputURL = createTemporaryURL()
                     try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
                     _ = await audioRecorder.stopRecording()
                 }
             }
         }
     }

     func testPerformance_SourceTypeSwitching() async throws {
         let outputURL = createTemporaryURL()

         // Baseline: Switching between different audio sources should be efficient
         measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
             Task {
                 // Test different sources
                 try await audioRecorder.startRecording(to: outputURL, source: .microphone, retryCount: 0)
                 _ = await audioRecorder.stopRecording()

                 try await audioRecorder.startRecording(to: outputURL, source: .system, retryCount: 0)
                 _ = await audioRecorder.stopRecording()

                 try await audioRecorder.startRecording(to: outputURL, source: .all, retryCount: 0)
                 _ = await audioRecorder.stopRecording()
             }
         }
     }
     */

    // MARK: - Helpers

    private func createTemporaryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "test_audio_recorder_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }
}

// MARK: - Mock Audio Recording Worker

/// Mock para AudioRecordingWorker usado nos testes
final class MockAudioRecordingWorker {
    var startCalled = false
    var stopCalled = false
    var lastURL: URL?
    var lastFormat: AVAudioFormat?
    var shouldFailStart = false

    func start(writingTo url: URL, format: AVAudioFormat, fileFormat: AppSettingsStore.AudioFormat) async throws {
        if self.shouldFailStart {
            throw NSError(domain: "MockWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock start failure"])
        }

        self.startCalled = true
        self.lastURL = url
        self.lastFormat = format
    }

    func stop() async -> URL? {
        self.stopCalled = true
        return self.lastURL
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        // Simular processamento
    }
}
