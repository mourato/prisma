import Foundation
import os.log
import SwiftUI

@MainActor
public class AISettingsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showAPIKey = false
    @Published public var apiKeyText = ""
    @Published public var connectionStatus: ConnectionStatus = .unknown

    private let logger = Logger(subsystem: "MeetingAssistant", category: "AISettingsViewModel")

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings
        self.apiKeyText = (try? KeychainManager.retrieve(for: .aiAPIKey)) ?? ""
    }

    public func saveAPIKey(_ value: String) {
        do {
            if !value.isEmpty {
                try KeychainManager.store(value, for: .aiAPIKey)
            } else {
                try KeychainManager.delete(for: .aiAPIKey)
            }
        } catch {
            self.logger.error("Failed to save API key to Keychain: \(error.localizedDescription)")
        }
    }

    public func testAPIConnection() {
        self.connectionStatus = .testing

        let urlString = self.settings.aiConfiguration.baseURL

        // Validate URL format and scheme
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased())
        else {
            self.connectionStatus = .failure("URL inválida")
            return
        }

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 5

                if let key = try? KeychainManager.retrieve(for: .aiAPIKey), !key.isEmpty {
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                }

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    if (200...299).contains(statusCode) {
                        self.connectionStatus = .success
                    } else {
                        self.connectionStatus = .failure("HTTP \(statusCode)")
                    }
                } else {
                    self.connectionStatus = .failure("Resposta inválida")
                }
            } catch {
                self.connectionStatus = .failure(error.localizedDescription)
            }
        }
    }
}
