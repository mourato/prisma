import Foundation
import Carbon.HIToolbox

// MARK: - Keyboard Shortcut Model

/// Represents a keyboard shortcut with modifiers and key code.
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    
    /// Human-readable display string for the shortcut.
    var displayString: String {
        var parts: [String] = []
        
        // Modifier keys
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        
        // Key name
        if let keyName = Self.keyName(for: keyCode) {
            parts.append(keyName)
        }
        
        return parts.joined()
    }
    
    /// Default shortcut: Cmd + Shift + R
    static let `default` = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    
    /// Maps key codes to their display names.
    private static func keyName(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_Space: return "Espaço"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return nil
        }
    }
}

// MARK: - AI Provider Configuration

/// Supported AI providers for post-processing transcriptions.
enum AIProvider: String, CaseIterable, Codable {
    case openai = "openai"
    case anthropic = "anthropic"
    case groq = "groq"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        case .custom: return "Personalizado"
        }
    }
    
    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .custom: return ""
        }
    }
    
    var icon: String {
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
struct AIConfiguration: Codable, Equatable {
    var provider: AIProvider
    var baseURL: String
    var selectedModel: String
    
    // NOTE: apiKey is NOT stored here - it's in Keychain.
    // This field exists only for Codable compatibility and migration.
    // It will always be empty after migration.
    private var _legacyApiKey: String = ""
    
    enum CodingKeys: String, CodingKey {
        case provider, baseURL, selectedModel
        case _legacyApiKey = "apiKey"  // For migration from old format
    }
    
    /// Default configuration with empty values.
    static let `default` = AIConfiguration(
        provider: .openai,
        baseURL: AIProvider.openai.defaultBaseURL,
        selectedModel: ""
    )
    
    /// Check if configuration is valid for making API calls.
    /// Checks Keychain for API key presence.
    var isValid: Bool {
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
class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()
    
    // MARK: - Keys
    
    private enum Keys {
        static let keyboardShortcut = "keyboardShortcut"
        static let aiConfiguration = "aiConfiguration"
        static let aiEnabled = "aiPostProcessingEnabled"
    }
    
    // MARK: - Published Properties
    
    @Published var keyboardShortcut: KeyboardShortcut {
        didSet { save(keyboardShortcut, forKey: Keys.keyboardShortcut) }
    }
    
    @Published var aiConfiguration: AIConfiguration {
        didSet { save(aiConfiguration, forKey: Keys.aiConfiguration) }
    }
    
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: Keys.aiEnabled) }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load keyboard shortcut
        if let data = UserDefaults.standard.data(forKey: Keys.keyboardShortcut),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            self.keyboardShortcut = shortcut
        } else {
            self.keyboardShortcut = .default
        }
        
        // Load AI configuration
        if let data = UserDefaults.standard.data(forKey: Keys.aiConfiguration),
           let config = try? JSONDecoder().decode(AIConfiguration.self, from: data) {
            self.aiConfiguration = config
        } else {
            self.aiConfiguration = .default
        }
        
        // Load AI enabled state
        self.aiEnabled = UserDefaults.standard.bool(forKey: Keys.aiEnabled)
    }
    
    // MARK: - Private Helpers
    
    /// Encodes and saves a Codable value to UserDefaults.
    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    /// Reset all settings to defaults.
    func resetToDefaults() {
        keyboardShortcut = .default
        aiConfiguration = .default
        aiEnabled = false
    }
}
