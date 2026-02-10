import AVFoundation
import Combine
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// View model for audio playback and waveform visualization.
@MainActor
public final class AudioPlayerViewModel: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var timer: AnyCancellable?

    @Published public var isPlaying = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var samples: [Float] = []

    public init() {}

    /// Loads an audio file from a URL.
    public func loadAudio(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayer = player
            duration = player.duration
            currentTime = 0
            isPlaying = false

            // For now, generate random-ish but static samples for this file
            generateSamples(for: url)
        } catch {
            print("Failed to load audio for playback: \(error)")
        }
    }

    /// Toggles between play and pause.
    public func togglePlayback() {
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            player.pause()
            stopTimer()
        } else {
            // If finished, reset to start
            if player.currentTime >= player.duration - 0.1 {
                player.currentTime = 0
            }
            player.play()
            startTimer()
        }
        isPlaying = player.isPlaying
    }

    /// Seeks to a specific time in the audio file.
    public func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        let targetTime = progress * duration
        player.currentTime = targetTime
        currentTime = targetTime
    }

    private func startTimer() {
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let player = audioPlayer else { return }
                currentTime = player.currentTime
                if !player.isPlaying {
                    isPlaying = false
                    stopTimer()
                }
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func generateSamples(for url: URL) {
        // TODO: Implement actual audio sample extraction
        // For Phase 1, we use a deterministic seed based on the filename to keep it consistent
        let seed = url.lastPathComponent.hashValue
        var generator = SeededRandomGenerator(seed: seed)

        let count = 40
        samples = (0..<count).map { _ in
            Float.random(in: 0.1...0.9, using: &generator)
        }
    }
}

/// Simple seeded LCRG for consistent waveforms across app restarts for same files.
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(abs(seed))
    }

    mutating func next() -> UInt64 {
        state = 2_862_933_555_777_941_757 &* state &+ 3_037_000_493
        return state
    }
}
