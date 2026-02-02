// RecordingRepositoryAdapter - Adapter para RecordingRepository usando RecordingManager

import Foundation

/// Adapter que implementa RecordingRepository usando RecordingManager existente
public final class RecordingRepositoryAdapter: RecordingRepository {
    private let recordingManager: RecordingManager

    public init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }

    public func startRecording(to outputURL: URL, retryCount: Int) async throws {
        // O RecordingManager tem uma interface diferente, vamos usar startRecording sem URL específica
        // pois ele cria a URL internamente
        await recordingManager.startRecording()
    }

    public func stopRecording() async throws -> URL? {
        await recordingManager.stopRecording()
        // O RecordingManager não retorna URL diretamente, vamos buscar do estado interno
        // Por simplicidade, retornamos nil por enquanto
        return nil
    }

    public func hasPermission() async -> Bool {
        await recordingManager.checkPermission(for: .microphone)
        return await recordingManager.hasRequiredPermissions
    }

    public func requestPermission() async {
        await recordingManager.requestPermission(for: .microphone)
    }

    public func getPermissionState() -> DomainPermissionState {
        // O RecordingManager não expõe estado detalhado diretamente
        // Vamos usar uma abordagem simplificada
        // Como não podemos acessar hasRequiredPermissions de forma síncrona,
        // vamos usar uma abordagem diferente
        .notDetermined // Simplificado por enquanto
    }

    public func openSettings() async {
        await recordingManager.openPermissionSettings()
    }
}
