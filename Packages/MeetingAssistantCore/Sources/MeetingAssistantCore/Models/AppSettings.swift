import Foundation

// MARK: - AI Provider Configuration

/// Supported AI providers for post-processing transcriptions.
public enum AIProvider: String, CaseIterable, Codable, Sendable {
    case openai
    case anthropic
    case groq
    case custom

    public var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .groq: "Groq"
        case .custom: "Personalizado"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .custom: ""
        }
    }

    public var icon: String {
        switch self {
        case .openai: "brain"
        case .anthropic: "sparkles"
        case .groq: "bolt.fill"
        case .custom: "server.rack"
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
        case _legacyApiKey = "apiKey" // For migration from old format
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
        return hasApiKey && !self.baseURL.isEmpty
    }

    /// Migrate legacy API key from UserDefaults to Keychain.
    /// Should be called once during app initialization.
    mutating func migrateLegacyApiKeyIfNeeded() {
        guard !self._legacyApiKey.isEmpty else { return }

        // Move to Keychain
        try? KeychainManager.store(self._legacyApiKey, for: .aiAPIKey)

        // Clear from struct (will be saved to UserDefaults without the key)
        self._legacyApiKey = ""
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
        static let isDiarizationEnabled = "isDiarizationEnabled"
    }

    // MARK: - Published Properties

    @Published public var aiConfiguration: AIConfiguration {
        didSet { self.save(self.aiConfiguration, forKey: Keys.aiConfiguration) }
    }

    @Published public var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(self.aiEnabled, forKey: Keys.aiEnabled) }
    }

    // MARK: - Post-Processing Properties

    /// Custom system prompt for post-processing.
    @Published public var systemPrompt: String {
        didSet { UserDefaults.standard.set(self.systemPrompt, forKey: Keys.systemPrompt) }
    }

    /// User-created prompts for post-processing.
    @Published public var userPrompts: [PostProcessingPrompt] {
        didSet { self.save(self.userPrompts, forKey: Keys.userPrompts) }
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
            UserDefaults.standard.set(self.postProcessingEnabled, forKey: Keys.postProcessingEnabled)
        }
    }

    /// Whether speaker diarization is enabled.
    @Published public var isDiarizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.isDiarizationEnabled, forKey: Keys.isDiarizationEnabled)
        }
    }

    /// Selected audio format for recordings.
    @Published public var audioFormat: AudioFormat {
        didSet {
            UserDefaults.standard.set(self.audioFormat.rawValue, forKey: PostProcessingKeys.audioFormat)
        }
    }

    /// Whether to merge audio files after recording.
    /// Default: true
    @Published public var shouldMergeAudioFiles: Bool {
        didSet {
            UserDefaults.standard.set(self.shouldMergeAudioFiles, forKey: PostProcessingKeys.shouldMergeAudioFiles)
        }
    }

    /// All available prompts (predefined + user-created).
    public var allPrompts: [PostProcessingPrompt] {
        PostProcessingPrompt.allPredefined + self.userPrompts
    }

    /// Currently selected prompt.
    public var selectedPrompt: PostProcessingPrompt? {
        guard let id = selectedPromptId else { return nil }
        return self.allPrompts.first { $0.id == id }
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
        self.isDiarizationEnabled = UserDefaults.standard.bool(forKey: Keys.isDiarizationEnabled)

        // Initialize Audio Format
        if let rawValue = UserDefaults.standard.string(forKey: PostProcessingKeys.audioFormat),
           let format = AudioFormat(rawValue: rawValue)
        {
            self.audioFormat = format
        } else {
            self.audioFormat = .wav
        }

        // Initialize Merge Setting
        if UserDefaults.standard.object(forKey: PostProcessingKeys.shouldMergeAudioFiles) == nil {
            self.shouldMergeAudioFiles = true
        } else {
            self.shouldMergeAudioFiles = UserDefaults.standard.bool(forKey: PostProcessingKeys.shouldMergeAudioFiles)
        }
    }

    // MARK: - Private Helpers

    /// Encodes and saves a Codable value to UserDefaults.
    private func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Reset all settings to defaults.
    public func resetToDefaults() {
        self.aiConfiguration = .default
        self.aiEnabled = false
        self.systemPrompt = AIPromptTemplates.defaultSystemPrompt
        self.userPrompts = []
        self.selectedPromptId = nil
        self.postProcessingEnabled = false
        self.isDiarizationEnabled = false
    }

    // MARK: - Prompt Management

    /// Adds a new user prompt.
    /// - Parameter prompt: The prompt to add.
    public func addPrompt(_ prompt: PostProcessingPrompt) {
        self.userPrompts.append(prompt)
    }

    /// Updates an existing user prompt.
    /// - Parameter prompt: The prompt with updated values.
    public func updatePrompt(_ prompt: PostProcessingPrompt) {
        guard let index = userPrompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        self.userPrompts[index] = prompt
    }

    /// Deletes a user prompt by ID.
    /// - Parameter id: The ID of the prompt to delete.
    public func deletePrompt(id: UUID) {
        self.userPrompts.removeAll { $0.id == id }
        if self.selectedPromptId == id {
            self.selectedPromptId = nil
        }
    }

    /// Resets the system prompt to default.
    public func resetSystemPrompt() {
        self.systemPrompt = AIPromptTemplates.defaultSystemPrompt
    }
}

// MARK: - General Settings Extension

public extension AppSettingsStore {
    private enum GeneralKeys {
        static let recordingsDirectory = "recordingsDirectory"
        static let autoStartRecording = "autoStartRecording"
    }

    /// Configured path for saving recordings.
    /// If empty or invalid, services should fallback to the default Application Support directory.
    var recordingsDirectory: String {
        get { UserDefaults.standard.string(forKey: GeneralKeys.recordingsDirectory) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.recordingsDirectory) }
    }

    /// Whether to automatically start recording when a meeting is detected.
    var autoStartRecording: Bool {
        get { UserDefaults.standard.bool(forKey: GeneralKeys.autoStartRecording) }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.autoStartRecording) }
    }

    // MARK: - Post-Processing Extension

    enum PostProcessingKeys {
        public static let audioFormat = "audioFormat"
        public static let shouldMergeAudioFiles = "shouldMergeAudioFiles"
    }

    /// Supported audio formats for recording.
    enum AudioFormat: String, CaseIterable, Codable, Sendable {
        case m4a
        case wav

        public var fileExtension: String {
            switch self {
            case .m4a: "m4a"
            case .wav: "wav"
            }
        }

        public var displayName: String {
            switch self {
            case .m4a: "AAC (.m4a)"
            case .wav: "WAV (Linear PCM)"
            }
        }
    }

    // Moved to main class body to support @Published storage
}
