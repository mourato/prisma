import Atomics
@preconcurrency import AVFoundation
import Foundation
import os.log

// MARK: - Audio Recording Worker

/// A thread-safe actor that handles Audio Processing and File Writing.
/// Extracted from AudioRecorder.swift to adhere to Single Responsibility Principle.
/// Uses Actor pattern for automatic thread safety isolation.
actor AudioRecordingWorker {
    // MARK: - State

    private var audioFile: AVAudioFile?
    private var currentURL: URL?

    // Atomic state for validation and lifecycle
    private let _hasReceivedValidBuffer = ManagedAtomic<Bool>(false)
    private let _isStopping = ManagedAtomic<Bool>(false)
    var hasReceivedValidBuffer: Bool {
        _hasReceivedValidBuffer.load(ordering: .relaxed)
    }

    // Callbacks - marked as Sendable since they are set from MainActor
    private var onPowerUpdate: (@Sendable (Float, Float) -> Void)?
    private var onError: (@Sendable (AudioRecorderError) -> Void)?

    // Non-isolated buffer queue for synchronous enqueue from tap
    private nonisolated let bufferQueue = AudioBufferQueue(capacity: 100)

    // Processing task
    private var processingTask: Task<Void, Never>?

    init() {}

    // MARK: - Callback Setters

    nonisolated func setOnPowerUpdate(_ callback: (@Sendable (Float, Float) -> Void)?) {
        Task { await self.setOnPowerUpdateIsolated(callback) }
    }

    nonisolated func setOnError(_ callback: (@Sendable (AudioRecorderError) -> Void)?) {
        Task { await self.setOnErrorIsolated(callback) }
    }

    private func setOnPowerUpdateIsolated(_ callback: (@Sendable (Float, Float) -> Void)?) {
        onPowerUpdate = callback
    }

    private func setOnErrorIsolated(_ callback: (@Sendable (AudioRecorderError) -> Void)?) {
        onError = callback
    }

    // MARK: - Property Accessors

    nonisolated func getHasReceivedValidBuffer() async -> Bool {
        await getHasReceivedValidBufferIsolated()
    }

    private func getHasReceivedValidBufferIsolated() -> Bool {
        hasReceivedValidBuffer
    }

    // MARK: - Lifecycle

    func start(writingTo url: URL, format: AVAudioFormat, fileFormat: AppSettingsStore.AudioFormat) async throws {
        // Reset state
        audioFile = nil
        _hasReceivedValidBuffer.store(false, ordering: .relaxed)
        _isStopping.store(false, ordering: .relaxed)

        // Cancel any existing processing task
        processingTask?.cancel()
        processingTask = nil

        // Clear buffer queue
        bufferQueue.clear()

        // Prepare file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // Create Audio Settings based on format
        let settings: [String: Any]
        let commonFormat: AVAudioCommonFormat
        let interleaved: Bool

        switch fileFormat {
        case .m4a:
            settings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            commonFormat = .pcmFormatFloat32
            interleaved = false

        case .wav:
            // Linear PCM 32-bit Float (High Quality, larger size)
            // Using Float32 matches the engine's internal format, avoiding conversion overhead
            settings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
            commonFormat = .pcmFormatFloat32
            interleaved = false // AVAudioFile handles interleaving for us if needed, but we provide non-interleaved buffers
        }

        // Create Audio File
        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: commonFormat,
            interleaved: interleaved
        )
        audioFile = file
        currentURL = url

        // Start processing task
        processingTask = Task {
            await self.processBuffers()
        }
    }

    func stop() async -> URL? {
        // Mark as stopping but don't cancel yet - allow loop to drain queue
        _isStopping.store(true, ordering: .relaxed)

        // Wait for task to finish processing remaining buffers
        await processingTask?.value
        processingTask = nil

        // Clear queue
        bufferQueue.clear()

        let url = currentURL
        audioFile = nil // Close file
        currentURL = nil

        return url
    }

    // MARK: - Processing

    nonisolated func process(_ buffer: AVAudioPCMBuffer) {
        bufferQueue.enqueue(buffer)
    }

    private func processBuffers() async {
        while true {
            if let buffer = bufferQueue.dequeue() {
                processBufferInternal(buffer)
            } else {
                // If queue is empty AND we are stopping, we can exit the loop
                if _isStopping.load(ordering: .relaxed) || Task.isCancelled {
                    break
                }
                // Wait a bit before checking again
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }

    private func processBufferInternal(_ buffer: AVAudioPCMBuffer) {
        calculateMeters(from: buffer)

        // Lock removed; serialized by queue

        guard let audioFile else { return }
        guard buffer.frameLength > 0 else { return }

        do {
            try audioFile.write(from: buffer)
            _hasReceivedValidBuffer.store(true, ordering: .relaxed)
        } catch {
            onError?(AudioRecorderError.fileWriteFailed(error))
        }
    }

    private func calculateMeters(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return }

        var maxRMS: Float = 0.0
        var maxPeak: Float = 0.0

        // Check all channels to find sound (in case mic is not on channel 0)
        for ch in 0..<channelCount {
            let channel = channelData[ch]
            var sum: Float = 0.0
            var peak: Float = 0.0

            for frame in stride(from: 0, to: frameLength, by: 10) {
                let sample = abs(channel[frame])
                if sample > peak { peak = sample }
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength / 10))
            if rms > maxRMS { maxRMS = rms }
            if peak > maxPeak { maxPeak = peak }
        }

        // Use a wider range for metering to capture more subtle sounds
        let averagePowerDb = 20.0 * log10(max(maxRMS, 1e-10))
        let peakPowerDb = 20.0 * log10(max(maxPeak, 1e-10))

        onPowerUpdate?(averagePowerDb, peakPowerDb)
    }
}
