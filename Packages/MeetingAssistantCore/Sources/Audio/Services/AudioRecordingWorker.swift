import Atomics
@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreInfrastructure
import os.lock

// MARK: - Audio Recording Worker

/// A thread-safe actor that handles Audio Processing and File Writing.
/// Extracted from AudioRecorder.swift to adhere to Single Responsibility Principle.
/// Uses Actor pattern for automatic thread safety isolation.
actor AudioRecordingWorker {
        private final class BufferSignalStorage: @unchecked Sendable {
            private let continuationLock = OSAllocatedUnfairLock<AsyncStream<Void>.Continuation?>(initialState: nil)

            func set(_ continuation: AsyncStream<Void>.Continuation?) {
                continuationLock.withLock { $0 = continuation }
            }

            func yield() {
                continuationLock.withLock { $0?.yield(()) }
            }

            func finishAndClear() {
                continuationLock.withLock { continuation in
                    continuation?.finish()
                    continuation = nil
                }
            }
        }

    struct MeterSnapshot {
        let averagePowerDB: Float
        let peakPowerDB: Float
        let barPowerDBLevels: [Float]
        let deltaTime: TimeInterval
    }

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
    private var onPowerUpdate: (@Sendable (Float, Float, [Float]) -> Void)?
    private var onError: (@Sendable (AudioRecorderError) -> Void)?
    private var onProcessedBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var meteringBarCount = 0

    /// Non-isolated buffer queue for synchronous enqueue from tap
    private nonisolated let bufferQueue = AudioBufferQueue(capacity: 100)

    /// Processing task
    private var processingTask: Task<Void, Never>?
    private let bufferSignalStorage = BufferSignalStorage()

    init() {}

    // MARK: - Callback Setters

    nonisolated func setOnPowerUpdate(_ callback: (@Sendable (Float, Float, [Float]) -> Void)?) {
        Task { await self.setOnPowerUpdateIsolated(callback) }
    }

    nonisolated func setOnError(_ callback: (@Sendable (AudioRecorderError) -> Void)?) {
        Task { await self.setOnErrorIsolated(callback) }
    }

    nonisolated func setOnProcessedBuffer(_ callback: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        Task { await self.setOnProcessedBufferIsolated(callback) }
    }

    nonisolated func setMeteringBarCount(_ barCount: Int) {
        Task { await self.setMeteringBarCountIsolated(barCount) }
    }

    private func setOnPowerUpdateIsolated(_ callback: (@Sendable (Float, Float, [Float]) -> Void)?) {
        onPowerUpdate = callback
    }

    private func setOnErrorIsolated(_ callback: (@Sendable (AudioRecorderError) -> Void)?) {
        onError = callback
    }

    private func setOnProcessedBufferIsolated(_ callback: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        onProcessedBuffer = callback
    }

    private func setMeteringBarCountIsolated(_ barCount: Int) {
        meteringBarCount = max(0, barCount)
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
        bufferSignalStorage.finishAndClear()

        // Clear buffer queue
        bufferQueue.clear()

        // Prepare file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        /// Create Audio Settings based on format
        /// Helper to generate settings
        func createSettings(for targetFormat: AppSettingsStore.AudioFormat) -> ([String: Any], AVAudioCommonFormat, Bool) {
            switch targetFormat {
            case .m4a:
                // Minimal AAC Settings
                (
                    [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: format.sampleRate,
                        AVNumberOfChannelsKey: 2,
                        AVEncoderBitRateKey: 128_000,
                    ],
                    .pcmFormatFloat32,
                    false
                )
            case .wav:
                (
                    [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: format.sampleRate,
                        AVNumberOfChannelsKey: 2,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false,
                    ],
                    .pcmFormatFloat32,
                    false
                )
            }
        }

        // Try to create file with requested format, fallback to WAV on failure
        do {
            let (settings, commonFormat, interleaved) = createSettings(for: fileFormat)
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: settings,
                commonFormat: commonFormat,
                interleaved: interleaved
            )
            currentURL = url
        } catch {
            print("Failed to initialize audio file with format \(fileFormat): \(error). Falling back to WAV.")
            // Fallback to WAV
            // Note: If original URL ended in .m4a, this might create a confusing file, but it will work.
            // Ideally we should change the extension, but we can't easily change the URL here as it's passed in.
            // coreaudiod will handle valid WAV headers in .m4a files usually, or we just accept it for now.
            let (wavSettings, wavCommon, wavInterleaved) = createSettings(for: .wav)
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: wavSettings,
                commonFormat: wavCommon,
                interleaved: wavInterleaved
            )
            currentURL = url
        }

        // Start processing task
        let bufferSignalStream = AsyncStream<Void> { continuation in
            self.bufferSignalStorage.set(continuation)
        }

        processingTask = Task {
            await self.processBuffers(bufferSignalStream)
        }
    }

    func stop() async -> URL? {
        // Mark as stopping but don't cancel yet - allow loop to drain queue
        _isStopping.store(true, ordering: .relaxed)
        bufferSignalStorage.yield()

        // Wait for task to finish processing remaining buffers
        await processingTask?.value
        processingTask = nil
        bufferSignalStorage.finishAndClear()

        // Clear queue after task completes
        bufferQueue.clear()

        // Close file safely
        let url = currentURL
        audioFile = nil
        currentURL = nil

        return url
    }

    // MARK: - Processing

    nonisolated func process(_ buffer: AVAudioPCMBuffer) {
        bufferQueue.enqueue(buffer)
        bufferSignalStorage.yield()
    }

    private func processBuffers(_ bufferSignalStream: AsyncStream<Void>) async {
        for await _ in bufferSignalStream {
            while let buffer = bufferQueue.dequeue() {
                processBufferInternal(buffer)
            }

            if _isStopping.load(ordering: .relaxed) || Task.isCancelled {
                break
            }
        }

        while let buffer = bufferQueue.dequeue() {
            processBufferInternal(buffer)
        }
    }

    private func processBufferInternal(_ buffer: AVAudioPCMBuffer) {
        if let snapshot = Self.makeMeterSnapshot(from: buffer, barCount: meteringBarCount) {
            onPowerUpdate?(
                snapshot.averagePowerDB,
                snapshot.peakPowerDB,
                snapshot.barPowerDBLevels
            )
        }

        // Lock removed; serialized by queue

        guard let audioFile else { return }
        guard buffer.frameLength > 0 else { return }

        onProcessedBuffer?(buffer)

        do {
            try audioFile.write(from: buffer)
            _hasReceivedValidBuffer.store(true, ordering: .relaxed)
        } catch {
            onError?(AudioRecorderError.fileWriteFailed(error))
        }
    }

    nonisolated static func makeMeterSnapshot(
        from buffer: AVAudioPCMBuffer,
        barCount: Int
    ) -> MeterSnapshot? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return nil }

        var maxRMS: Float = 0.0
        var maxPeak: Float = 0.0

        // Check all channels to find sound (in case mic is not on channel 0)
        for ch in 0..<channelCount {
            let channel = channelData[ch]
            var sum: Float = 0.0
            var peak: Float = 0.0

            for frame in 0..<frameLength {
                let sample = abs(channel[frame])
                if sample > peak { peak = sample }
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            if rms > maxRMS { maxRMS = rms }
            if peak > maxPeak { maxPeak = peak }
        }

        let sanitizedBarCount = max(0, barCount)
        let barPowerDBLevels: [Float] = if sanitizedBarCount == 0 {
            []
        } else {
            (0..<sanitizedBarCount).map { bucketIndex in
                let start = Int(Double(bucketIndex) * Double(frameLength) / Double(sanitizedBarCount))
                let end = Int(Double(bucketIndex + 1) * Double(frameLength) / Double(sanitizedBarCount))
                guard end > start else { return -160.0 }

                var maxBucketPeak: Float = 0.0

                for channelIndex in 0..<channelCount {
                    let channel = channelData[channelIndex]

                    for frame in start..<end {
                        let sample = abs(channel[frame])
                        if sample > maxBucketPeak {
                            maxBucketPeak = sample
                        }
                    }
                }

                return 20.0 * log10(max(maxBucketPeak, 1e-10))
            }
        }

        // Use a wider range for metering to capture more subtle sounds
        let averagePowerDb = 20.0 * log10(max(maxRMS, 1e-10))
        let peakPowerDb = 20.0 * log10(max(maxPeak, 1e-10))

        return MeterSnapshot(
            averagePowerDB: averagePowerDb,
            peakPowerDB: peakPowerDb,
            barPowerDBLevels: barPowerDBLevels,
            deltaTime: Double(frameLength) / buffer.format.sampleRate
        )
    }
}
