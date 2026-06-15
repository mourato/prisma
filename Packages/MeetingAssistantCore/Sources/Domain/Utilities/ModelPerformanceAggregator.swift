import Foundation

public enum ModelPerformanceAggregator {

    public static func computeAnalysis(transcriptions: [Transcription]) -> ModelPerformanceAnalysis {
        let totalTranscripts = transcriptions.count
        let totalWithData = transcriptions.count(where: { $0.transcriptionDuration > 0 })
        let totalAudioDuration = transcriptions.reduce(0) { $0 + $1.meeting.duration }
        let totalProcessed = transcriptions.count(where: { $0.isPostProcessed && $0.postProcessingDuration > 0 })

        let transcriptionStats = processStats(
            for: transcriptions,
            modelNameKeyPath: \.modelName,
            durationKeyPath: \.transcriptionDuration,
            audioDurationKeyPath: \.meeting.duration
        )

        let enhancementStats = processStats(
            for: transcriptions,
            modelNameKeyPath: \.postProcessingModel,
            durationKeyPath: \.postProcessingDuration
        )

        return ModelPerformanceAnalysis(
            totalTranscripts: totalTranscripts,
            totalWithData: totalWithData,
            totalAudioDuration: totalAudioDuration,
            totalProcessed: totalProcessed,
            transcriptionModels: transcriptionStats,
            enhancementModels: enhancementStats
        )
    }

    static func processStats(
        for transcriptions: [Transcription],
        modelNameKeyPath: KeyPath<Transcription, String>,
        durationKeyPath: KeyPath<Transcription, Double>,
        audioDurationKeyPath: KeyPath<Transcription, TimeInterval>? = nil
    ) -> [ModelPerformanceStat] {
        let relevant = transcriptions.filter { $0[keyPath: durationKeyPath] > 0 }
        let grouped = Dictionary(grouping: relevant) { $0[keyPath: modelNameKeyPath] }

        return grouped.map { modelName, items in
            let fileCount = items.count
            let totalProcessingTime = items.reduce(0) { $0 + $1[keyPath: durationKeyPath] }
            let avgProcessingTime = totalProcessingTime / Double(fileCount)
            let totalAudioDuration = items.reduce(0) { $0 + $1.meeting.duration }
            let avgAudioDuration = totalAudioDuration / Double(fileCount)

            var speedFactor = 0.0
            if let audioDurationKeyPath, totalProcessingTime > 0 {
                let audioTotal = items.reduce(0) { $0 + $1[keyPath: audioDurationKeyPath] }
                speedFactor = audioTotal / totalProcessingTime
            }

            return ModelPerformanceStat(
                name: modelName,
                fileCount: fileCount,
                totalProcessingTime: totalProcessingTime,
                avgProcessingTime: avgProcessingTime,
                avgAudioDuration: avgAudioDuration,
                speedFactor: speedFactor
            )
        }
        .sorted { $0.avgProcessingTime < $1.avgProcessingTime }
    }

    static func processStats(
        for transcriptions: [Transcription],
        modelNameKeyPath: KeyPath<Transcription, String?>,
        durationKeyPath: KeyPath<Transcription, Double>,
        audioDurationKeyPath: KeyPath<Transcription, TimeInterval>? = nil
    ) -> [ModelPerformanceStat] {
        let relevant = transcriptions.filter {
            $0[keyPath: modelNameKeyPath] != nil && $0[keyPath: durationKeyPath] > 0
        }
        let grouped = Dictionary(grouping: relevant) { $0[keyPath: modelNameKeyPath] ?? "Unknown" }

        return grouped.map { modelName, items in
            let fileCount = items.count
            let totalProcessingTime = items.reduce(0) { $0 + $1[keyPath: durationKeyPath] }
            let avgProcessingTime = totalProcessingTime / Double(fileCount)
            let totalAudioDuration = items.reduce(0) { $0 + $1.meeting.duration }
            let avgAudioDuration = totalAudioDuration / Double(fileCount)

            var speedFactor = 0.0
            if let audioDurationKeyPath, totalProcessingTime > 0 {
                let audioTotal = items.reduce(0) { $0 + $1[keyPath: audioDurationKeyPath] }
                speedFactor = audioTotal / totalProcessingTime
            }

            return ModelPerformanceStat(
                name: modelName,
                fileCount: fileCount,
                totalProcessingTime: totalProcessingTime,
                avgProcessingTime: avgProcessingTime,
                avgAudioDuration: avgAudioDuration,
                speedFactor: speedFactor
            )
        }
        .sorted { $0.avgProcessingTime < $1.avgProcessingTime }
    }
}
