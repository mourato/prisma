import Atomics
@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreInfrastructure
import MeetingAssistantCoreCommon

extension AudioRecorder {
    nonisolated private func installMicDiagnosticsTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        peakBits: ManagedAtomic<UInt32>,
        probeWorker: AudioRecordingWorker?
    ) {
        inputNode.installTap(
            onBus: Constants.tapBusNumber,
            bufferSize: 1_024,
            format: format
        ) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            guard channelCount > 0, frameLength > 0 else { return }

            var peak: Float = 0
            for ch in 0..<channelCount {
                let channel = channelData[ch]
                for frame in stride(from: 0, to: frameLength, by: 4) {
                    let sample = abs(channel[frame])
                    if sample > peak { peak = sample }
                }
            }

            probeWorker?.process(buffer)

            if peak > 0 {
                var updated = false
                while !updated {
                    let currentBits = peakBits.load(ordering: .relaxed)
                    let currentPeak = Float(bitPattern: currentBits)
                    guard peak > currentPeak else { break }
                    updated = peakBits.compareExchange(
                        expected: currentBits,
                        desired: peak.bitPattern,
                        ordering: .relaxed
                    ).exchanged
                }
            }
        }
    }

    func logDeviceDiagnostics(for deviceID: AudioObjectID, label: String) {
        let name = deviceManager.getDeviceName(for: deviceID) ?? "Unknown"
        let uid = deviceManager.getDeviceUID(for: deviceID) ?? "Unknown"
        let channels = deviceManager.getInputChannelCount(for: deviceID) ?? -1
        let volume = deviceManager.getInputVolume(for: deviceID)
        let isMuted = deviceManager.getInputMute(for: deviceID)

        var extra: [String: Any] = [
            "label": label,
            "deviceID": deviceID,
            "name": name,
            "uid": uid,
            "inputChannels": channels,
        ]

        if let volume {
            extra["inputVolume"] = volume
        }
        if let isMuted {
            extra["inputMuted"] = isMuted
        }

        AppLogger.info("Input device diagnostics", category: .recordingManager, extra: extra)
    }

    func startMicDiagnostics(for inputNode: AVAudioInputNode) {
        stopMicDiagnostics(for: inputNode)

        let format = inputNode.inputFormat(forBus: Constants.tapBusNumber)
        micDiagnosticsPeakBits.store(0, ordering: .relaxed)
        startMicProbeRecording(format: format)

        // Avoid capturing `self` (MainActor-isolated) inside the audio tap callback.
        // AVAudioEngine invokes tap blocks from a real-time audio thread/queue.
        let peakBits = micDiagnosticsPeakBits
        let probeWorker = micProbeWorker
        installMicDiagnosticsTap(on: inputNode, format: format, peakBits: peakBits, probeWorker: probeWorker)

        isMicDiagnosticsTapInstalled = true
        micDiagnosticsTimer?.invalidate()
        micDiagnosticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let peakBits = micDiagnosticsPeakBits.exchange(0, ordering: .relaxed)
            let peak = Float(bitPattern: peakBits)
            let db = 20.0 * log10(max(peak, 1e-6))
            AppLogger.debug(
                "Mic input diagnostic",
                category: .recordingManager,
                extra: ["peakAmplitude": peak, "peakDb": db]
            )
        }
    }

    func stopMicDiagnostics(for inputNode: AVAudioInputNode) {
        micDiagnosticsTimer?.invalidate()
        micDiagnosticsTimer = nil

        if isMicDiagnosticsTapInstalled {
            inputNode.removeTap(onBus: Constants.tapBusNumber)
            isMicDiagnosticsTapInstalled = false
        }

        micDiagnosticsPeakBits.store(0, ordering: .relaxed)
        stopMicProbeRecording()
    }

    func startMicProbeRecording(format: AVAudioFormat) {
        micProbeStopTask?.cancel()
        micProbeStopTask = nil

        let worker = AudioRecordingWorker()
        micProbeWorker = worker

        let fileURL = makeMicProbeURL(label: "engine")
        AppLogger.info(
            "Mic probe recording started",
            category: .recordingManager,
            extra: ["path": fileURL.path]
        )

        Task {
            do {
                try await worker.start(writingTo: fileURL, format: format, fileFormat: .wav)
            } catch {
                AppLogger.error("Mic probe failed to start", category: .recordingManager, error: error)
                return
            }

            micProbeStopTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    self.stopMicProbeRecording()
                }
            }
        }

        startAvAudioRecorderProbe()
    }

    func stopMicProbeRecording() {
        micProbeStopTask?.cancel()
        micProbeStopTask = nil

        guard let worker = micProbeWorker else { return }
        micProbeWorker = nil

        Task {
            let url = await worker.stop()
            if let url {
                AppLogger.info(
                    "Mic probe recording saved",
                    category: .recordingManager,
                    extra: ["path": url.path]
                )
            }
        }

        stopAvAudioRecorderProbe()
    }

    func makeMicProbeURL(label: String) -> URL {
        let recordingsPath = AppSettingsStore.shared.recordingsDirectory
        let baseURL: URL = if recordingsPath.isEmpty {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("MeetingAssistant/recordings", isDirectory: true)
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        } else {
            URL(fileURLWithPath: recordingsPath, isDirectory: true)
        }

        let diagnosticsURL = baseURL.appendingPathComponent("diagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        return diagnosticsURL.appendingPathComponent("mic_probe_\(label)_\(timestamp).wav")
    }

    func startAvAudioRecorderProbe() {
        micRecorderProbeStopTask?.cancel()
        micRecorderProbeStopTask = nil

        let url = makeMicProbeURL(label: "recorder")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            micRecorderProbe = recorder

            AppLogger.info(
                "Mic recorder probe started",
                category: .recordingManager,
                extra: ["path": url.path]
            )

            micRecorderProbeStopTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    self.stopAvAudioRecorderProbe()
                }
            }
        } catch {
            AppLogger.error("Mic recorder probe failed to start", category: .recordingManager, error: error)
        }
    }

    @MainActor
    func stopAvAudioRecorderProbe() {
        micRecorderProbeStopTask?.cancel()
        micRecorderProbeStopTask = nil

        guard let recorder = micRecorderProbe else { return }
        micRecorderProbe = nil

        recorder.stop()

        let url = recorder.url
        let duration = recorder.currentTime
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0

        AppLogger.info(
            "Mic recorder probe saved",
            category: .recordingManager,
            extra: ["path": url.path, "duration": duration, "bytes": size]
        )
    }
}
