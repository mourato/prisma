import Foundation

// MARK: - AI Provider Configuration

/// Supported AI providers for post-processing transcriptions.
public enum AIProvider: String, CaseIterable, Codable, Sendable {
    case openai = "openai"
    case anthropic = "anthropic"
    case groq = "groq"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        case .custom: return "Personalizado"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .custom: return ""
        }
    }

    public var icon: String {
        switch self {
        case .openai: return "brain"
        case .anthropic: return "sparkles"
        case .groq: return "bolt.fill"
        case .custom: return "server.rack"
        }
    }
}

/// Configuration for AI model post-processing.
/// NOTE: API key is stored securely in Keychain, not in this struct.
public struct AIConfiguration: Codable, Equatable, Sendable {
    public var provider: AIProvider
    public var baseURL: String
    public var selectedModel: String

    // NOTE: apiKey is NOT stored here - it's in Keychain.
    // This field exists only for Codable compatibility and migration.
    // It will always be empty after migration.
    private var _legacyApiKey: String = ""

    enum CodingKeys: String, CodingKey {
        case provider, baseURL, selectedModel
        case _legacyApiKey = "apiKey"  // For migration from old format
    }

    public init(provider: AIProvider, baseURL: String, selectedModel: String) {
        self.provider = provider
        self.baseURL = baseURL
        self.selectedModel = selectedModel
    }

    /// Default configuration with empty values.
    public static let `default` = AIConfiguration(
        provider: .openai,
        baseURL: AIProvider.openai.defaultBaseURL,
        selectedModel: ""
    )

    /// Check if configuration is valid for making API calls.
    /// Checks Keychain for API key presence.
    public var isValid: Bool {
        let hasApiKey = KeychainManager.exists(for: .aiAPIKey)
        return hasApiKey && !baseURL.isEmpty
    }

    /// Migrate legacy API key from UserDefaults to Keychain.
    /// Should be called once during app initialization.
    mutating func migrateLegacyApiKeyIfNeeded() {
        guard !_legacyApiKey.isEmpty else { return }

        // Move to Keychain
        try? KeychainManager.store(_legacyApiKey, for: .aiAPIKey)

        // Clear from struct (will be saved to UserDefaults without the key)
        _legacyApiKey = ""
    }
}

// MARK: - App Settings Store

/// Centralized settings manager using UserDefaults.
@MainActor
public class AppSettingsStore: ObservableObject {
    public static let shared = AppSettingsStore()

    // MARK: - Keys

    private enum Keys {

        static let aiConfiguration = "aiConfiguration"
        static let aiEnabled = "aiPostProcessingEnabled"
        static let systemPrompt = "postProcessingSystemPrompt"
        static let userPrompts = "postProcessingUserPrompts"
        static let selectedPromptId = "postProcessingSelectedPromptId"
        static let postProcessingEnabled = "postProcessingEnabled"
    }

    // MARK: - Published Properties

    @Published public var aiConfiguration: AIConfiguration {
        didSet { save(aiConfiguration, forKey: Keys.aiConfiguration) }
    }

    @Published public var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: Keys.aiEnabled) }
    }

    // MARK: - Post-Processing Properties

    /// Custom system prompt for post-processing.
    @Published public var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    /// User-created prompts for post-processing.
    @Published public var userPrompts: [PostProcessingPrompt] {
        didSet { save(userPrompts, forKey: Keys.userPrompts) }
    }

    /// Currently selected prompt ID for post-processing.
    @Published public var selectedPromptId: UUID? {
        didSet {
            if let id = selectedPromptId {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.selectedPromptId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.selectedPromptId)
            }
        }
    }

    /// Whether post-processing is enabled.
    @Published public var postProcessingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(postProcessingEnabled, forKey: Keys.postProcessingEnabled)
        }
    }

    /// All available prompts (predefined + user-created).
    public var allPrompts: [PostProcessingPrompt] {
        PostProcessingPrompt.allPredefined + userPrompts
    }

    /// Currently selected prompt.
    public var selectedPrompt: PostProcessingPrompt? {
        guard let id = selectedPromptId else { return nil }
        return allPrompts.first { $0.id == id }
    }

    // MARK: - Initialization

    private init() {

        // Load AI configuration
        if let data = UserDefaults.standard.data(forKey: Keys.aiConfiguration),
            let config = try? JSONDecoder().decode(AIConfiguration.self, from: data)
        {
            self.aiConfiguration = config
        } else {
            self.aiConfiguration = .default
        }

        // Load AI enabled state
        self.aiEnabled = UserDefaults.standard.bool(forKey: Keys.aiEnabled)

        // Load post-processing settings
        self.systemPrompt =
            UserDefaults.standard.string(forKey: Keys.systemPrompt)
            ?? AIPromptTemplates.defaultSystemPrompt

        if let data = UserDefaults.standard.data(forKey: Keys.userPrompts),
            let prompts = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data)
        {
            self.userPrompts = prompts
        } else {
            self.userPrompts = []
        }

        if let idString = UserDefaults.standard.string(forKey: Keys.selectedPromptId),
            let id = UUID(uuidString: idString)
        {
            self.selectedPromptId = id
        } else {
            self.selectedPromptId = nil
        }

        self.postProcessingEnabled = UserDefaults.standard.bool(forKey: Keys.postProcessingEnabled)
    }

    // MARK: - Private Helpers

    /// Encodes and saves a Codable value to UserDefaults.
    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Reset all settings to defaults.
    public func resetToDefaults() {

        aiConfiguration = .default
        aiEnabled = false
        systemPrompt = AIPromptTemplates.defaultSystemPrompt
        userPrompts = []
        selectedPromptId = nil
        postProcessingEnabled = false
    }

    // MARK: - Prompt Management

    /// Adds a new user prompt.
    /// - Parameter prompt: The prompt to add.
    public func addPrompt(_ prompt: PostProcessingPrompt) {
        userPrompts.append(prompt)
    }

    /// Updates an existing user prompt.
    /// - Parameter prompt: The prompt with updated values.
    public func updatePrompt(_ prompt: PostProcessingPrompt) {
        guard let index = userPrompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        userPrompts[index] = prompt
    }

    /// Deletes a user prompt by ID.
    /// - Parameter id: The ID of the prompt to delete.
    public func deletePrompt(id: UUID) {
        userPrompts.removeAll { $0.id == id }
        if selectedPromptId == id {
            selectedPromptId = nil
        }
    }

    /// Resets the system prompt to default.
    public func resetSystemPrompt() {
        systemPrompt = AIPromptTemplates.defaultSystemPrompt
    }
}
