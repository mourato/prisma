import Combine
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
    private let keychain: KeychainProvider
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    public init(
        settings: AppSettingsStore = .shared,
        keychain: KeychainProvider = DefaultKeychainProvider(),
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.keychain = keychain
        self.session = session
        self.apiKeyText = (try? keychain.retrieve(for: .aiAPIKey)) ?? ""

        // Reactive persistence for API Key
        self.$apiKeyText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.persistAPIKey(newValue)
            }
            .store(in: &self.cancellables)
    }

    private func persistAPIKey(_ value: String) {
        do {
            if !value.isEmpty {
                try self.keychain.store(value, for: .aiAPIKey)
                self.logger.info("API Key successfully persisted to Keychain")
            } else {
                try self.keychain.delete(for: .aiAPIKey)
                self.logger.info("API Key removed from Keychain")
            }
        } catch {
            self.logger.error("Failed to persist API key: \(error.localizedDescription)")
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
            self.connectionStatus = .failure(NSLocalizedString("settings.ai.connection.invalid_url", comment: ""))
            return
        }

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 5

                if let key = try? self.keychain.retrieve(for: .aiAPIKey), !key.isEmpty {
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                }

                let (_, response) = try await self.session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    if (200...299).contains(statusCode) {
                        self.connectionStatus = .success
                    } else {
                        self.connectionStatus = .failure("HTTP \(statusCode)")
                    }
                } else {
                    self.connectionStatus = .failure(NSLocalizedString("settings.ai.connection.invalid_response", comment: ""))
                }
            } catch {
                self.connectionStatus = .failure(error.localizedDescription)
            }
        }
    }
}
