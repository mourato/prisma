import Foundation
import SwiftUI

@MainActor
public class ServiceSettingsViewModel: ObservableObject {
    @Published public var transcriptionStatus: ConnectionStatus = .unknown

    private let transcriptionClient: TranscriptionClient

    public init(transcriptionClient: TranscriptionClient = .shared) {
        self.transcriptionClient = transcriptionClient
    }

    public func testConnection() {
        transcriptionStatus = .testing

        Task {
            do {
                let isHealthy = try await self.transcriptionClient.healthCheck()
                self.transcriptionStatus = isHealthy ? .success : .failure(nil)
            } catch {
                self.transcriptionStatus = .failure(error.localizedDescription)
            }
        }
    }
}
