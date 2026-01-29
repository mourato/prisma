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
        case .custom: "ai.provider.custom".localized
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

// MARK: - App Language Configuration

/// Supported app languages for UI localization.
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case english
    case portuguese

    public var displayName: String {
        switch self {
        case .system:
            "settings.general.language.system".localized
        case .english:
            "settings.general.language.english".localized
        case .portuguese:
            "settings.general.language.portuguese".localized
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
        return hasApiKey && !baseURL.isEmpty
    }

    /// Migrate legacy API key from UserDefaults to Keychain.
    /// Should be called once during app initialization.
    mutating func migrateLegacyApiKeyIfNeeded() {
        guard !_legacyApiKey.isEmpty else { return }

        // Move to Keychain
        do {
            try KeychainManager.store(_legacyApiKey, for: .aiAPIKey)
        } catch {
            AppLogger.error(
                "Failed to store legacy API key in Keychain during migration",
                category: .general,
                error: error
            )
            // For migration scenarios, continuing without logging the error is acceptable
        }

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
        static let isDiarizationEnabled = "isDiarizationEnabled"
        static let minSpeakers = "minSpeakers"
        static let maxSpeakers = "maxSpeakers"
        static let numSpeakers = "numSpeakers"
        static let selectedLanguage = "selectedLanguage"
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

    /// Whether speaker diarization is enabled.
    @Published public var isDiarizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDiarizationEnabled, forKey: Keys.isDiarizationEnabled)
        }
    }

    /// Minimum number of speakers for diarization.
    @Published public var minSpeakers: Int? {
        didSet {
            UserDefaults.standard.set(minSpeakers, forKey: Keys.minSpeakers)
        }
    }

    /// Maximum number of speakers for diarization.
    @Published public var maxSpeakers: Int? {
        didSet {
            UserDefaults.standard.set(maxSpeakers, forKey: Keys.maxSpeakers)
        }
    }

    /// Fixed number of speakers for diarization.
    @Published public var numSpeakers: Int? {
        didSet {
            UserDefaults.standard.set(numSpeakers, forKey: Keys.numSpeakers)
        }
    }

    /// Selected audio format for recordings.
    @Published public var audioFormat: AudioFormat {
        didSet {
            UserDefaults.standard.set(audioFormat.rawValue, forKey: PostProcessingKeys.audioFormat)
        }
    }

    /// Whether to merge audio files after recording.
    /// Default: true
    @Published public var shouldMergeAudioFiles: Bool {
        didSet {
            UserDefaults.standard.set(shouldMergeAudioFiles, forKey: PostProcessingKeys.shouldMergeAudioFiles)
        }
    }

    /// Selected app language.
    @Published public var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
            applyLanguage(selectedLanguage)
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
            aiConfiguration = config
        } else {
            aiConfiguration = .default
        }

        aiEnabled = UserDefaults.standard.bool(forKey: Keys.aiEnabled)
        systemPrompt = UserDefaults.standard.string(forKey: Keys.systemPrompt)
            ?? AIPromptTemplates.defaultSystemPrompt

        if let data = UserDefaults.standard.data(forKey: Keys.userPrompts),
           let prompts = try? JSONDecoder().decode([PostProcessingPrompt].self, from: data)
        {
            userPrompts = prompts
        } else {
            userPrompts = []
        }

        postProcessingEnabled = UserDefaults.standard.bool(forKey: Keys.postProcessingEnabled)
        isDiarizationEnabled = UserDefaults.standard.bool(forKey: Keys.isDiarizationEnabled)

        minSpeakers = UserDefaults.standard.object(forKey: Keys.minSpeakers) as? Int
        maxSpeakers = UserDefaults.standard.object(forKey: Keys.maxSpeakers) as? Int
        numSpeakers = UserDefaults.standard.object(forKey: Keys.numSpeakers) as? Int

        let rawFormat = UserDefaults.standard.string(forKey: PostProcessingKeys.audioFormat)
        audioFormat = rawFormat.flatMap { AudioFormat(rawValue: $0) } ?? .m4a

        selectedPromptId = UserDefaults.standard.string(forKey: Keys.selectedPromptId)
            .flatMap { UUID(uuidString: $0) }

        if UserDefaults.standard.object(forKey: PostProcessingKeys.shouldMergeAudioFiles) == nil {
            shouldMergeAudioFiles = true
        } else {
            shouldMergeAudioFiles = UserDefaults.standard.bool(forKey: PostProcessingKeys.shouldMergeAudioFiles)
        }

        let rawLang = UserDefaults.standard.string(forKey: Keys.selectedLanguage)
        selectedLanguage = rawLang.flatMap { AppLanguage(rawValue: $0) } ?? .system

        applyLanguage(selectedLanguage)
    }

    // MARK: - Private Helpers

    /// Encodes and saves a Codable value to UserDefaults.
    private func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Apply language preference to the system.
    private func applyLanguage(_ language: AppLanguage) {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .portuguese:
            UserDefaults.standard.set(["pt"], forKey: "AppleLanguages")
        }
        // UserDefaults synchronizes automatically
    }

    /// Reset all settings to defaults.
    public func resetToDefaults() {
        aiConfiguration = .default
        aiEnabled = false
        systemPrompt = AIPromptTemplates.defaultSystemPrompt
        userPrompts = []
        selectedPromptId = nil
        postProcessingEnabled = false
        isDiarizationEnabled = false
        minSpeakers = nil
        maxSpeakers = nil
        numSpeakers = nil
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

// MARK: - General Settings Extension

public extension AppSettingsStore {
    private enum GeneralKeys {
        static let recordingsDirectory = "recordingsDirectory"
        static let autoStartRecording = "autoStartRecording"
        static let showSettingsOnLaunch = "showSettingsOnLaunch"
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

    /// Whether to show the settings window on app launch.
    var showSettingsOnLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: GeneralKeys.showSettingsOnLaunch) }
        set { UserDefaults.standard.set(newValue, forKey: GeneralKeys.showSettingsOnLaunch) }
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
