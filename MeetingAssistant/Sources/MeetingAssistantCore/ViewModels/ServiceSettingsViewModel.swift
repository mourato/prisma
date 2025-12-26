import Foundation
import SwiftUI

@MainActor
public class ServiceSettingsViewModel: ObservableObject {
    @Published public var transcriptionStatus: ConnectionStatus = .unknown

    public init() {}

    public func testConnection() {
        self.transcriptionStatus = .testing

        Task {
            do {
                let isHealthy = try await TranscriptionClient.shared.healthCheck()
                self.transcriptionStatus = isHealthy ? .success : .failure(nil)
            } catch {
                self.transcriptionStatus = .failure(error.localizedDescription)
            }
        }
    }
}
